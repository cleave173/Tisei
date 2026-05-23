"""add vocab_lesson_progress

Revision ID: 4a1b8e7d9c01
Revises: 3f2a0e355bfa
Create Date: 2026-05-13 08:50:00

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "4a1b8e7d9c01"
down_revision: Union[str, None] = "3f2a0e355bfa"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "vocab_lesson_progress",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "topic_id",
            sa.Integer(),
            sa.ForeignKey("topics.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("lesson_index", sa.Integer(), nullable=False),
        sa.Column("cards_done", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("listening_done", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("mc_done", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("speaking_done", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("xp_earned", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "user_id", "topic_id", "lesson_index", name="uq_vlp_user_topic_idx"
        ),
    )


def downgrade() -> None:
    op.drop_table("vocab_lesson_progress")
