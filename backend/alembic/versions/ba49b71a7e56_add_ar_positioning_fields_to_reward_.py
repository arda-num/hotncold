"""Add AR positioning fields to reward templates

Revision ID: ba49b71a7e56
Revises: e7983b2fa3d3
Create Date: 2026-02-09 14:56:08.675599

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ba49b71a7e56'
down_revision: Union[str, None] = 'e7983b2fa3d3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add AR positioning fields to reward_templates table
    op.add_column('reward_templates', sa.Column('bearing_degrees', sa.Float(), nullable=True))
    op.add_column('reward_templates', sa.Column('elevation_degrees', sa.Float(), nullable=True))
    
    # Update existing rows with default values
    op.execute("UPDATE reward_templates SET bearing_degrees = 45.0 WHERE bearing_degrees IS NULL")
    op.execute("UPDATE reward_templates SET elevation_degrees = 0.0 WHERE elevation_degrees IS NULL")
    
    # Alter columns to be NOT NULL
    op.alter_column('reward_templates', 'bearing_degrees', nullable=False)
    op.alter_column('reward_templates', 'elevation_degrees', nullable=False)


def downgrade() -> None:
    # Remove AR positioning fields from reward_templates table
    op.drop_column('reward_templates', 'elevation_degrees')
    op.drop_column('reward_templates', 'bearing_degrees')
