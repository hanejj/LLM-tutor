## API 문서

모든 엔드포인트는 `/api/v1` 프리픽스를 사용합니다. 인증이 필요한 엔드포인트는 `Authorization: Bearer <JWT>` 헤더가 필요합니다.

### 인증 (Authentication)

#### POST `/auth/register`
회원가입

**Request:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123"
  }
}
```

**Response (201 Created):**
```json
{
  "message": "회원가입이 완료되었습니다.",
  "token": "<jwt-token>",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "membership": {
      "id": 3,
      "name": "체험",
      "features": "대화",
      "expires_at": "2025-12-01T00:00:00.000Z"
    }
  }
}
```

> 신규 가입 시, 기본적으로 `체험` 멤버십이 자동 부여되며, 대화 쿠폰이 초기 1개 지급됩니다.

#### POST `/auth/login`
로그인

**Request:**
```json
{
  "auth": {
    "email": "user@example.com",
    "password": "password123"
  }
}
```

**Response (200 OK):**
```json
{
  "message": "로그인에 성공했습니다.",
  "token": "<jwt-token>",
  "user": {
    "id": 1,
    "email": "user@example.com",
      "membership": {
        "id": 2,
        "name": "프리미엄",
        "features": "학습,대화,분석",
        "expires_at": "2025-12-31T00:00:00.000Z"
      }
  }
}
```

#### POST `/auth/logout`
로그아웃 (인증 필요)

**Response (200 OK):**
```json
{ "message": "로그아웃되었습니다." }
```

#### GET `/auth/me`
현재 사용자 정보 조회 (인증 필요)

**Response (200 OK):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
      "membership": {
        "id": 2,
        "name": "프리미엄",
        "features": "학습,대화,분석",
        "expires_at": "2025-12-31T00:00:00.000Z"
      }
  }
}
```

#### GET `/auth/validate`
토큰 유효성 검사 (인증 필요)

**Response (200 OK):**
```json
{
  "message": "유효한 토큰입니다.",
  "user": {
    "id": 1,
    "email": "user@example.com",
      "membership": {
        "id": 2,
        "name": "프리미엄",
        "features": "학습,대화,분석",
        "expires_at": "2025-12-31T00:00:00.000Z"
      }
  }
}
```

### 멤버십 (Memberships)

#### GET `/memberships`
멤버십 목록 조회

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "베이직",
    "features": ["학습", "대화"],
    "expires_at": "2025-12-01T00:00:00.000Z",
    "coupon_count": 0
  }
]
```

#### POST `/memberships` (인증 필요)
멤버십 생성

**Request:**
```json
{
  "membership": {
    "name": "프리미엄",
    "features": "학습,대화",
    "expires_at": "2025-12-31T00:00:00.000Z",
    "coupon_count": 30
  }
}
```

**Response (201 Created):**
```json
{
  "id": 2,
  "name": "프리미엄",
  "features": ["학습", "대화"],
  "expires_at": "2025-12-31T00:00:00.000Z",
  "coupon_count": 30
}
```

#### DELETE `/memberships/:id` (인증 필요)
멤버십 삭제. 사용자가 연결되어 있으면 409 반환.

**Response (204 No Content | 409 Conflict):**
```json
{ "error": "이 멤버십을 사용하는 사용자가 있어 삭제할 수 없습니다." }
```

### 결제 (Payments)

#### POST `/payments` (인증 필요)
멤버십 구매(Mock 결제). 금액은 모의 결제로 `0` 처리됩니다. 카드 정보는 옵션입니다.

**Request:**
```json
{
  "payment": {
    "membership_id": 1,
    "payment_method": "card",
    "card_number": "4111111111111111",
    "expiry_date": "12/25",
    "cvv": "123"
  }
}
```

**Response (200 OK):**
```json
{
  "message": "결제가 완료되었습니다.",
  "payment": {
    "id": "PAY_XXXX",
    "amount": 0,
    "status": "completed",
    "membership_name": "베이직"
  },
  "user": {
    "id": 1,
    "email": "user@example.com",
    "chat_coupons": 30,
    "membership": {
      "id": 1,
      "name": "베이직",
      "features": ["학습", "대화"],
      "expires_at": "2025-12-01T00:00:00.000Z",
      "coupon_count": 30
    }
  }
}
```

### 채팅 (Chat)

모든 채팅 엔드포인트는 인증이 필요합니다. 기능명은 `대화`를 사용합니다.

#### POST `/chat/start`
채팅 세션 시작(쿠폰 1장 차감). 멱등키로 중복 차감을 방지할 수 있습니다.

**Request:**
```json
{
  "user_id": 1,
  "idempotency_key": "optional-unique-key"
}
```

**Response (200 OK):**
```json
{
  "message": "채팅 세션이 시작되었습니다.",
  "remaining_chat_coupons": 9
}
```

#### POST `/chat/message`
AI에게 메시지 전송(일반). 최근 메시지 일부만 사용하여 응답 생성.

**Request:**
```json
{
  "user_id": 1,
  "messages": [
    { "role": "user", "content": "안녕하세요!" }
  ]
}
```

**Response (200 OK):**
```json
{
  "response": "안녕하세요! 무엇을 도와드릴까요?",
  "remaining_chat_coupons": 9
}
```

#### POST `/chat/message_stream`
AI에게 메시지 전송(스트리밍, SSE). 시작 신호 `type:start` 후 청크가 이어집니다.

**Request:**
```json
{
  "user_id": 1,
  "messages": [
    { "role": "user", "content": "안녕하세요!" }
  ]
}
```

**Response (SSE):**
```
data: {"type":"start"}
data: {"type":"chunk","content":"안녕하세요! "}
data: {"type":"chunk","content":"무엇을 도와드릴까요?"}
data: {"type":"done","remaining_chat_coupons":9}
```

오류 시:
```
data: {"type":"error","error":"...","details":"..."}
```

### 사용자 (Users)

#### GET `/users` (관리자용)
전체 사용자 목록

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "email": "user@example.com",
    "chat_coupons": 30,
    "membership": {
      "id": 1,
      "name": "베이직",
      "features": ["학습", "대화"],
      "expires_at": "2025-12-01T00:00:00.000Z"
    }
  }
]
```

#### GET `/users/:id`
사용자 정보 조회

**Response (200 OK):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "chat_coupons": 30,
  "membership": {
    "id": 1,
    "name": "베이직",
    "features": ["학습", "대화"],
    "expires_at": "2025-12-01T00:00:00.000Z",
    "coupon_count": 30
  }
}
```

#### POST `/users/:id/assign_membership` (관리자용)
특정 사용자에게 멤버십 부여. `대화` 기능 포함 시 쿠폰을 추가 지급합니다. 기본은 멤버십의 `coupon_count`, 0 이하인 경우 정책값(`베이직=0`, `프리미엄=30`) 사용.

**Request:**
```json
{ "membership_id": 2 }
```

**Response (200 OK):**
```json
{ "message": "Membership assigned successfully", "user": { /* UserSerializer */ } }
```

#### DELETE `/users/:id/remove_membership` (관리자용)
사용자에서 멤버십 회수, 쿠폰은 0으로 초기화.

**Response (200 OK):**
```json
{ "message": "Membership removed successfully", "user": { /* ... */ } }
```

#### GET `/users/:id/membership_status`
멤버십 상태 확인(`available` | `expired` | `unavailable`).

**Response (200 OK):**
```json
{ "status": "available", "membership": { "name": "베이직", "features": ["학습","대화"], "expires_at": "2025-12-01T00:00:00.000Z" } }
```

#### GET or POST `/users/:id/feature_available`
특정 기능 사용 가능 여부 확인. `feature=대화`인 경우 남은 쿠폰도 함께 반환.

**Response (200 OK):**
```json
{ "status": "available", "feature": "대화", "remaining_chat_coupons": 9 }
```

#### POST `/users/:id/purchase_membership`
사용자 단건 구매 플로우(Mock). 정책은 `assign_membership`과 동일.

**Request:**
```json
{ "membership_id": 2 }
```

**Response (200 OK):**
```json
{ "message": "Membership successfully purchased!", "user": { /* UserSerializer */ } }
```

#### POST `/users/:id/start_chat`
해당 사용자 기준으로 채팅 세션 시작(쿠폰 1장 차감).

**Response (200 OK):**
```json
{ "message": "Chat session started", "remaining_chat_coupons": 9 }
```

---

에러 응답 공통 형식
```json
{ "error": "메시지", "details": "선택적 상세" }
```

권한/검증 오류 예시
```json
{ "message": "인증 토큰이 필요합니다." }
{ "message": "유효하지 않은 토큰입니다." }
{ "error": "요청 파라미터가 올바르지 않습니다.", "details": "..." }
```


