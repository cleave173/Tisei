"""add cefr_level and sublevel to words

Revision ID: 19e02955616a
Revises: 0001_initial
Create Date: 2026-05-04 12:20:45.799636

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "19e02955616a"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # The cefr_level enum already exists (used by topics.level). Reuse it.
    cefr = sa.Enum("A1", "A2", "B1", "B2", "C1", "C2", name="cefr_level", create_type=False)
    op.add_column(
        "words",
        sa.Column("level", cefr, nullable=False, server_default="A1"),
    )
    op.add_column(
        "words",
        sa.Column("sublevel", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_index(op.f("ix_words_level"), "words", ["level"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_words_level"), table_name="words")
    op.drop_column("words", "sublevel")
    op.drop_column("words", "level")
