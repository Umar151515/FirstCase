from starlette.exceptions import HTTPException


class BodyLimitMiddleware:
    """Bound streamed bodies before multipart parsing can exhaust temporary storage."""

    def __init__(self, app, maximum: int):
        self.app = app
        self.maximum = maximum

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        received = 0

        async def bounded_receive():
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.maximum:
                    raise HTTPException(413, "Запрос превышает допустимый размер")
            return message

        await self.app(scope, bounded_receive, send)
