# FirstCase API v1

Base `/api/v1`. JSON snake_case, integer IDs, timestamps ISO8601 UTC. Protected calls use `Authorization: Bearer <access_token>`. Collections use `{items: [...], total: N}`; query `offset=0&limit=20` (1..100). Errors `{error:{code,key,message,details?}}`: `key` is a stable message key, `message` is localized using `Accept-Language: ru|ky` (Russian fallback). Validation details contain machine-readable `loc` and `type`; they never echo private input or raw library messages. 401 invalid auth, 403 forbidden, 404 unavailable, 409 invalid state/duplicate, 422 validation. Category names and system notification titles use the same request locale; user-written content stays as submitted. Public resources are readable without auth unless stated otherwise.

## Identity and profiles

- `GET /config` → `{mode: "demo"|"production"}`.
- `POST /auth/telegram` `{init_data: string}` → `{access_token,token_type:"bearer",user:User}`.
- **Demo only, routes absent in production:** `GET /auth/demo-users` → collection User; `POST /auth/demo-login` `{user_id:int}` → token response above.
- `GET /auth/me`, `GET /users/me` → own User; `PATCH /users/me` `{display_name?,bio?,specialization?,skills?:string[],city?,work_links?:https-url[],onboarding_completed?:bool,language?:"ru"|"ky",avatar_attachment_id?:int|null}` → User. Upload an image first, then claim its ID. `null` removes the current photo. Arbitrary avatar URLs are never accepted. Custom photos survive Telegram sign-in; Telegram remains the fallback for users without a custom photo. Language is persisted for bot replies and delivery; Telegram language initializes new profiles only.
- `GET /users?q=&city=&specialization=` → collection PublicUser; `GET /users/{id}` → PublicUser.
- PublicUser: `{id,display_name,avatar_url:null|string,avatar_attachment_id:null|int,bio,specialization,skills:[],city,work_links:[],rating:float,review_count:int,completed_orders:int,verified_cases:int,created_at}`. Custom `avatar_url` resolves to `/api/v1/uploads/{id}`. No Telegram identity/username in public DTOs. User additionally includes saved `language: "ru"|"ky"`.
- User adds `{telegram_id:null|int,username:null|string,role:"user"|"admin",status:"active"|"blocked",is_demo:bool,onboarding_completed:bool}`.
- `GET /categories` → collection `{id,name,slug,sort_order}`.

## Tasks and applications

- Task AI policy `ai_policy`: `no_ai` (no AI), `consultation` (advice only, human creates the material), `ai_allowed` (AI-created material permitted). Default `ai_allowed`. Create/update accept this field; `GET /tasks?ai_policy=` filters it. The value is copied into Order on assignment and cannot change afterward.
- Task create/update additionally accepts `cover_attachment_id:int|null`; `null` removes a cover. It must be an owned image, distinct from private order/report/profile assets. The backend binds it to the task automatically; it may also be included in `attachment_ids`. Task DTO includes `cover_attachment_id` and `cover:Attachment|null`. Only the selected cover is public, while the task is published and visible and its customer is active. Other task files remain private.

- Task: `{id,customer_id,customer:PublicUser,category_id,category:{id,name,slug,sort_order},title,description,expected_result,deadline,max_revisions,payment_type:"free"|"tips",city,status:"published"|"assigned"|"completed"|"cancelled",is_hidden,application_count,attachment_ids:[],created_at,updated_at}`.
- `GET /tasks?q=&category_id=&status=&city=&sort=newest|oldest|deadline&mine=false&created_after=&created_before=` → collection Task. `mine=true` requires auth. Date bounds are optional timezone-aware ISO8601 timestamps (inclusive).
- `POST /tasks` `{category_id,title,description,expected_result,deadline:ISO8601,max_revisions:0..10,payment_type:"free"|"tips",city?,attachment_ids?:int[]}` → Task 201.
- `GET /tasks/{id}` → Task; `PATCH /tasks/{id}` same optional fields → Task; `POST /tasks/{id}/cancel` → Task. Editing/cancel only customer before assignment.
- Application: `{id,task_id,performer_id,performer:PublicUser,message,proposed_deadline,comment,status:"pending"|"accepted"|"rejected"|"withdrawn",created_at}`.
- `POST /tasks/{id}/applications` `{message,proposed_deadline:ISO8601,comment?:string}` → Application 201.
- `GET /tasks/{id}/applications` → collection Application (customer sees all; performer sees own).
- `GET /applications?mine=true` → own applications; `POST /applications/{id}/accept` → Order (atomic assignment); `POST /applications/{id}/reject` → Application; `POST /applications/{id}/withdraw` → Application.

## Orders, chat, results, reviews

- Order additionally returns the agreed `ai_policy`. `POST /orders/{id}/submit` accepts `ai_usage:"no_ai"|"consultation"|"ai_assisted"` (default `no_ai`) and `ai_disclosure:string` (max 2000). Consultation and AI-created material require a disclosure. Violations of the agreed policy return 422 `ai_policy_violation`; missing disclosure returns `ai_disclosure_required`. Every versioned deliverable includes these fields.

- Order: `{id,task_id,task:Task,customer_id,performer_id,customer:PublicUser,performer:PublicUser,status,revisions_used,max_revisions,created_at,accepted_at:null|date,completed_at:null|date}`.
- statuses: `assigned → in_progress → submitted → revision_requested → submitted → accepted_pending_review → completed`. Customer review closes order. Cancellation before acceptance; dispute by either participant before completion.
- `GET /orders?role=customer|performer&status=` → participant collection; `GET /orders/{id}` → Order, participants only.
- `POST /orders/{id}/start`, `/accept`, `/cancel`, `/dispute` → Order. `/request-revision` `{reason:string}` → Order.
- `POST /orders/{id}/submit` `{description,links?:https-url[],attachment_ids?:int[]}` → Order; creates versioned deliverable.
- `GET /orders/{id}/deliverables` → collection `{id,order_id,performer_id,description,links:[],attachment_ids:[],version,created_at}`.
- `GET /orders/{id}/events` → collection `{id,order_id,actor_id,type,details:object,created_at}`.
- `GET /orders/{id}/messages?after_id=&before_id=&offset=&limit=&latest=` → chronological collection Message; polling supported. `latest=true` selects the newest `limit` matching messages but returns them oldest-first. `before_id` loads earlier history, `after_id` fetches new messages without gaps. Without these flags the existing offset contract is unchanged.
- `POST /orders/{id}/messages` `{text?:string,attachment_ids?:int[]}` → Message 201. Message `{id,order_id,author_id,author:PublicUser,text,attachment_ids:[],created_at}`.
- `GET /orders/{id}/telegram` → current Telegram invitation or `null`, participants only (including no blanket admin access). Invitation `{id,order_id,requested_by,status:"pending"|"accepted"|"declined"|"cancelled",my_username:null|string,peer_username:null|string,created_at,responded_at}`. `peer_username` is returned only after mutual consent; declined/cancelled invitations expose no contacts.
- `POST /orders/{id}/telegram` `{username}` → invitation 201. Accepts a username, `@username` or `https://t.me/username`; stores the normalized handle separately from public profiles and chat evidence. At most one pending or accepted invitation per order. Cancelled orders reject new invitations.
- `POST /orders/{id}/telegram/{invite_id}/respond` `{action:"accept"|"decline"|"cancel",username?:string}` → invitation. The recipient accepts with their own username or declines. The sender can withdraw a pending invitation; either participant can cancel an accepted handoff. Stale/duplicate decisions return 409. Both sides receive localized notifications without contact data. Opening `https://t.me/{peer_username}` is a separate user action; the application does not send Telegram messages or change order status.
- `GET /orders/{id}/reviews` → collection Review, participants only. `POST /orders/{id}/reviews` `{rating:1..5,comment?:string}` → Review 201. Customer comment required. Review `{id,order_id,author_id,recipient_id,rating,comment,created_at}`.

## Portfolio privacy

- Case create/edit additionally accepts `ai_usage` and `ai_disclosure` for ordinary work. A verified case always derives both from the final accepted deliverable; editing them returns 403. Case DTO includes both fields, but verified free-text disclosure is returned only to the owner or audited moderator because it may contain private source details. Public verified cases expose only the usage enum.
- Case create/edit and visibility updates accept `cover_attachment_id:int|null`, returned as `cover_attachment_id` and `cover:Attachment|null`. Anonymous cases reject covers. Ordinary cases may claim an owned image. Verified covers must be an image from the source task/order or a fresh owned image bound to that private case; publication requires customer consent for the exact attachment ID, including freshly uploaded covers. A customer may consent to those case-bound files through the existing consent endpoint. Revocation immediately removes the cover from public DTOs and public downloads. A visibility update replaces selected evidence and cover (`null`/omission removes the cover).

- `GET /portfolio?user_id=&mine=false` → collection Case; `GET /portfolio/{id}` → Case. Private only owner. Public DTOs never expose source order/customer IDs unless explicitly consented.
- `POST /portfolio` `{order_id?:int,title,description,result,visibility:"private"|"anonymous"|"public",attachment_ids?:int[],message_ids?:int[],show_customer?:bool}` → Case 201. Without order is an ordinary unverified work. Verified requires completed order and performer identity.
- `PATCH /portfolio/{id}` `{title?,description?,result?}` → Case. `PATCH /portfolio/{id}/visibility` `{visibility,show_customer?:bool,attachment_ids?:int[],message_ids?:int[]}` → Case.
- Case `{id,owner_id,title,description,result,visibility,verified,category:null|Category,completed_at:null|date,customer:null|PublicUser,review:null|{rating,comment},evidence:{attachments:Attachment[],messages:[{text,created_at}]},created_at}`. Anonymous suppresses customer, review comment, messages and source attachments. Private content does not leak through list/detail/uploads.
- `PUT /orders/{id}/privacy-consent` `{allow_identity:bool,attachment_ids:int[],message_ids:int[]}` → consent (customer only). Applies to exact IDs, reversible; no blanket chat consent. Both sides opt in: performer selects publication; customer grants specific permissions. Revocation immediately hides evidence and download access.

## Uploads and tips

- `POST /uploads` multipart `file` → Attachment 201 `{id,filename,mime_type,size,url:"/api/v1/uploads/{id}"}`. Auth required. Images PNG/JPEG/WebP, PDF, text/plain and ZIP up to configured limit; bytes checked.
- `GET /uploads/{id}` → protected binary. Owner or participants of linked object only; public evidence only with live consent. No static upload directory.
- `GET /uploads/{id}/metadata` → Attachment using exactly the same access checks as binary download. Images are validated and re-encoded to remove EXIF/GPS metadata. Current custom avatars are public only for active users; replacing/removing an avatar revokes the previous public access. Selecting an avatar or cover never grants access to the owner's other attachments. Public case media require visible case and active owner.
- `GET /tips/settings`, `PUT /tips/settings` `{payment_method,qr_attachment_id:null|int,payment_url:null|https-url,enabled:bool,public_consent:bool}` → settings. Owner only; QR upload must belong to owner and be image.
- `GET /users/{id}/tips` → enabled settings only with explicit public consent or completed-order customer; no transfer confirmation/payment endpoints.

## Reports, notifications and admin

- `POST /reports` `{target_type:"user"|"task"|"message"|"portfolio"|"review"|"order",target_id,reason:"spam"|"fraud"|"abuse"|"prohibited_content"|"agreement_violation"|"rating_manipulation"|"other",description,attachment_ids?:int[]}` → Report 201.
- `GET /reports` own reports; `GET /reports/{id}` own or admin. Report `{id,reporter_id,target_type,target_id,reason,description,status:"pending"|"in_review"|"resolved"|"rejected",moderator_comment,attachment_ids:[],created_at,updated_at}`.
- `GET /notifications` → own collection `{id,type,title,body,link,read_at,created_at}`; `POST /notifications/{id}/read` → notification.
- Admin role required: `GET /admin/stats` → `{users,active_tasks,completed_orders,applications,reviews,verified_cases,open_reports}`.
- `GET /admin/users?q=&status=`, `/admin/tasks?status=`, `/admin/orders?status=`, `/admin/reports?status=`, `/admin/moderation-actions` → collections.
- `PATCH /admin/users/{id}` `{status:"active"|"blocked",reason}` → User.
- `PATCH /admin/tasks/{id}` `{is_hidden:bool,reason}` → Task.
- `PATCH /admin/reports/{id}` `{status,moderator_comment}` → Report.
- `POST /admin/reports/{id}/evidence-access` `{reason}` → `{report,order:null|Order,messages:[],attachments:[],portfolio:null|Case}`. Only open report or disputed order; privacy access audited. Normal admin order list grants no blanket private-chat access.
- `GET /admin/reports/{id}/attachments/{attachment_id}?reason=` → binary evidence, exact report scope, every access audited. Returned evidence attachment URLs use this route. Download responses use `Cache-Control: private, no-store`.
- `GET /admin/orders/{id}/events` → paginated state history. `POST /admin/orders/{id}/resolve-dispute` `{action:"cancel"|"resume",reason}` → Order, audited and participants notified.

Health: `GET /health` process; `GET /health/ready` checks DB.
