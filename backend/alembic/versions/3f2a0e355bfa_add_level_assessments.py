"""add level_assessments table and profiles.cefr_level

Revision ID: 3f2a0e355bfa
Revises: 19e02955616a
Create Date: 2026-05-05 15:00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "3f2a0e355bfa"
down_revision: Union[str, None] = "19e02955616a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Reuse existing cefr_level enum (created in 0001_initial). Use postgresql.ENUM
    # explicitly with create_type=False — alembic's auto-create logic ignores
    # create_type on sa.Enum inside op.create_table.
    cefr = postgresql.ENUM(
        "A1", "A2", "B1", "B2", "C1", "C2", name="cefr_level", create_type=False
    )

    # 1. profiles.cefr_level (nullable until placement test is taken)
    op.add_column("profiles", sa.Column("cefr_level", cefr, nullable=True))

    # 2. assessment_kind enum + level_assessments table.
    # Use raw SQL with IF NOT EXISTS guard. We pass create_type=False on every
    # column reference below so alembic doesn't attempt to recreate the type.
    op.execute(
        "DO $$ BEGIN"
        " IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='assessment_kind') THEN"
        " CREATE TYPE assessment_kind AS ENUM ('placement', 'level_up');"
        " END IF;"
        " END $$;"
    )

    op.create_table(
        "level_assessments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "language_id",
            sa.Integer(),
            sa.ForeignKey("languages.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "kind",
            postgresql.ENUM(
                "placement", "level_up", name="assessment_kind", create_type=False
            ),
            nullable=False,
        ),
        sa.Column("from_level", cefr, nullable=True),
        sa.Column("to_level", cefr, nullable=True),
        sa.Column(
            "scores_by_level",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column("total_correct", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_questions", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("passed", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column(
            "taken_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_level_assessments_user_id", "level_assessments", ["user_id"]
    )
    op.create_index(
        "ix_level_assessments_language_id", "level_assessments", ["language_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_level_assessments_language_id", table_name="level_assessments")
    op.drop_index("ix_level_assessments_user_id", table_name="level_assessments")
    op.drop_table("level_assessments")
    sa.Enum(name="assessment_kind").drop(op.get_bind(), checkfirst=True)
    op.drop_column("profiles", "cefr_level")
