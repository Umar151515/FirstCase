"""Import every mapper before Alembic or external workers access metadata."""

from shared.features.applications.models import Application as Application
from shared.features.auth.models import DemoMarker as DemoMarker
from shared.features.chat.models import Message as Message
from shared.features.deliverables.models import Deliverable as Deliverable
from shared.features.moderation.models import ModerationAction as ModerationAction
from shared.features.notifications.models import Notification as Notification
from shared.features.orders.models import Order as Order
from shared.features.orders.models import OrderEvent as OrderEvent
from shared.features.portfolio.models import PortfolioCase as PortfolioCase
from shared.features.portfolio.models import PortfolioEvidence as PortfolioEvidence
from shared.features.portfolio.models import PrivacyConsent as PrivacyConsent
from shared.features.reports.models import Report as Report
from shared.features.reviews.models import Review as Review
from shared.features.tasks.models import Category as Category
from shared.features.tasks.models import Task as Task
from shared.features.tips.models import TipSettings as TipSettings
from shared.features.uploads.models import Attachment as Attachment
from shared.features.users.models import User as User
