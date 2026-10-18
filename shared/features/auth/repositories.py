from shared.features.users.repositories import UserRepository


class AuthRepository(UserRepository):
    async def demo_users(self):
        return await self.list(
            self.model.is_demo.is_(True),
            self.model.status == "active",
            limit=100,
            order_by=self.model.id,
        )
