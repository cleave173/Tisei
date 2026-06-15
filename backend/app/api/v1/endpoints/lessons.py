from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user, get_db
from app.models import (
    Lesson,
    Question,
    QuestionAttempt,
    QuestionType,
    Topic,
    User,
    UserProgress,
)
from app.schemas.learning import (
    LessonDetailOut,
    LessonSummaryOut,
    QuestionOut,
    SubmitLessonIn,
    SubmitLessonOut,
)
from app.services import achievement_service, progress_service

router = APIRouter()


@router.get("/by-topic/{topic_id}", response_model=list[LessonSummaryOut])
async def list_lessons_by_topic(
    topic_id: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[LessonSummaryOut]:
    topic = await db.get(Topic, topic_id)
    if topic is None:
        raise HTTPException(404, "Topic not found")

    lessons = (
        await db.execute(
            select(Lesson).where(Lesson.topic_id == topic_id).order_by(Lesson.order, Lesson.id)
        )
    ).scalars().all()

    progress_rows = (
        await db.execute(
            select(UserProgress).where(
                UserProgress.user_id == current.id,
                UserProgress.lesson_id.in_([l.id for l in lessons]) if lessons else False,
            )
        )
    ).scalars().all()
    progress_by_lesson = {p.lesson_id: p for p in progress_rows}

    out: list[LessonSummaryOut] = []
    for l in lessons:
        p = progress_by_lesson.get(l.id)
        out.append(
            LessonSummaryOut(
                id=l.id,
                title=l.title,
                description=l.description,
                type=l.type.value,
                order=l.order,
                xp_reward=l.xp_reward,
                estimated_minutes=l.estimated_minutes,
                is_completed=bool(p and p.is_completed),
                score=p.score if p else 0,
                progress=(p.score / 100.0) if (p and p.score) else 0.0,
            )
        )
    return out


@router.get("/{lesson_id}", response_model=LessonDetailOut)
async def get_lesson(
    lesson_id: int,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LessonDetailOut:
    lesson = (
        await db.execute(
            select(Lesson).options(selectinload(Lesson.questions)).where(Lesson.id == lesson_id)
        )
    ).scalar_one_or_none()
    if lesson is None:
        raise HTTPException(404, "Lesson not found")

    progress = (
        await db.execute(
            select(UserProgress).where(
                UserProgress.user_id == current.id, UserProgress.lesson_id == lesson_id
            )
        )
    ).scalar_one_or_none()

    return LessonDetailOut(
        id=lesson.id,
        title=lesson.title,
        description=lesson.description,
        type=lesson.type.value,
        order=lesson.order,
        xp_reward=lesson.xp_reward,
        estimated_minutes=lesson.estimated_minutes,
        is_completed=bool(progress and progress.is_completed),
        score=progress.score if progress else 0,
        progress=(progress.score / 100.0) if (progress and progress.score) else 0.0,
        questions=[
            QuestionOut(id=q.id, type=q.type.value, order=q.order, content=q.content)
            for q in sorted(lesson.questions, key=lambda x: x.order)
        ],
    )


def _grade_question(q: Question, answer) -> bool:
    """Type-specific grading. See models.content for content shapes."""
    content = q.content or {}
    if q.type == QuestionType.multiple_choice:
        return isinstance(answer, int) and answer == content.get("correct_index")
    if q.type == QuestionType.text_input:
        accepted = [a.strip().lower() for a in content.get("accepted_answers", [])]
        return isinstance(answer, str) and answer.strip().lower() in accepted
    if q.type == QuestionType.fill_blanks:
        return isinstance(answer, list) and answer == content.get("correct_order")
    return False


@router.post("/{lesson_id}/submit", response_model=SubmitLessonOut)
async def submit_lesson(
    lesson_id: int,
    payload: SubmitLessonIn,
    current: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SubmitLessonOut:
    lesson = (
        await db.execute(
            select(Lesson).options(selectinload(Lesson.questions)).where(Lesson.id == lesson_id)
        )
    ).scalar_one_or_none()
    if lesson is None:
        raise HTTPException(404, "Lesson not found")

    questions_by_id = {q.id: q for q in lesson.questions}
    per_question: list[dict] = []
    correct = 0
    mistakes = 0

    for ans in payload.answers:
        q = questions_by_id.get(ans.question_id)
        if q is None:
            continue
        ok = _grade_question(q, ans.answer)
        db.add(
            QuestionAttempt(
                user_id=current.id,
                question_id=q.id,
                is_correct=ok,
                answer_given=str(ans.answer),
            )
        )
        per_question.append({"question_id": q.id, "is_correct": ok})
        if ok:
            correct += 1
        else:
            mistakes += 1

    total = len(lesson.questions) or 1
    score = round(correct / total * 100)
    is_completed = score >= 60

    progress = (
        await db.execute(
            select(UserProgress).where(
                UserProgress.user_id == current.id, UserProgress.lesson_id == lesson_id
            )
        )
    ).scalar_one_or_none()
    was_completed = bool(progress and progress.is_completed)
    is_first_attempt = progress is None
    if is_completed and not was_completed:
        xp_earned = lesson.xp_reward
    elif is_first_attempt:
        xp_earned = max(1, lesson.xp_reward // 4)
    else:
        xp_earned = 0

    if progress is None:
        progress = UserProgress(
            user_id=current.id,
            lesson_id=lesson_id,
            attempts=1,
            score=score,
            mistakes=mistakes,
            is_completed=is_completed,
            time_spent_seconds=payload.time_spent_seconds,
            completed_at=datetime.now(timezone.utc) if is_completed else None,
        )
        db.add(progress)
    else:
        progress.attempts += 1
        progress.score = max(progress.score, score)
        progress.mistakes = mistakes
        progress.time_spent_seconds += payload.time_spent_seconds
        if is_completed and not progress.is_completed:
            progress.is_completed = True
            progress.completed_at = datetime.now(timezone.utc)

    if xp_earned > 0:
        await progress_service.apply_learning_activity_for_user(db, current.id, xp_earned)
        await achievement_service.grant_achievements(db, current.id)

    await db.commit()

    return SubmitLessonOut(
        score=score,
        total=total,
        correct=correct,
        mistakes=mistakes,
        xp_earned=xp_earned,
        is_completed=is_completed,
        per_question=per_question,
    )
