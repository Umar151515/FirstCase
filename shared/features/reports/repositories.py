from shared.features.common import Repository
from shared.features.reports.models import Report


class ReportRepository(Repository[Report]):
    def __init__(self, session):
        super().__init__(session, Report)
