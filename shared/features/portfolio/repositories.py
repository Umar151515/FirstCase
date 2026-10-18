from sqlalchemy import delete, or_, select

from shared.features.common import Repository
from shared.features.portfolio.models import PortfolioCase, PortfolioEvidence, PrivacyConsent
from shared.features.users.models import User


class PortfolioRepository(Repository[PortfolioCase]):
    def __init__(self, session):
        super().__init__(session, PortfolioCase)

    async def for_order(self, order_id):
        return await self.session.scalar(
            select(PortfolioCase).where(PortfolioCase.order_id == order_id)
        )

    async def consent(self, order_id):
        return await self.session.scalar(
            select(PrivacyConsent).where(PrivacyConsent.order_id == order_id)
        )

    async def evidence(self, case_id):
        return (
            await self.session.scalars(
                select(PortfolioEvidence)
                .where(PortfolioEvidence.case_id == case_id)
                .order_by(PortfolioEvidence.id)
            )
        ).all()

    async def replace_evidence(self, case_id, attachment_ids, message_ids):
        await self.session.execute(
            delete(PortfolioEvidence).where(PortfolioEvidence.case_id == case_id)
        )
        self.session.add_all(
            [PortfolioEvidence(case_id=case_id, attachment_id=i) for i in attachment_ids]
            + [PortfolioEvidence(case_id=case_id, message_id=i) for i in message_ids]
        )
        await self.session.flush()

    async def public_cases_for_attachment(self, attachment_id):
        return (
            await self.session.scalars(
                select(PortfolioCase)
                .outerjoin(PortfolioEvidence, PortfolioEvidence.case_id == PortfolioCase.id)
                .join(User, User.id == PortfolioCase.owner_id)
                .where(
                    or_(
                        PortfolioEvidence.attachment_id == attachment_id,
                        PortfolioCase.cover_attachment_id == attachment_id,
                    ),
                    PortfolioCase.visibility != "private",
                    PortfolioCase.is_hidden.is_(False),
                    User.status == "active",
                )
                .distinct()
            )
        ).all()
