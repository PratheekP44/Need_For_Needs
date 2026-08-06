# Campus Essentials Backend

Node.js + Express backend for the Campus Essentials (Need For Needs) smart locker platform.

## Current phase

**Phase 10 — BLE Communication Protocol Design** (docs + reference framing only)

Backend payment/order APIs remain as delivered in Phase 9. BLE radio, Flutter UI, and firmware are **not** implemented in Phase 10.

See: [`../docs/ble-protocol/`](../docs/ble-protocol/) and [`../protocol/ble/`](../protocol/ble/).

## Architecture

```text
Physical                 Business
--------                 --------
Locker                   Item
  └─ Box <──────────── Stock
                           ↑
User → Cart → Cart Items ─┘
         ↓
       Order
         ↓
      Payment (Razorpay)
```

- A **Box** remains a physical compartment only
- **Stock** links one Box to one Item
- One Box can have only one Stock record
- One cart/order can only contain items from **one locker**
- Payment success is trusted **only after backend Razorpay signature verification**

## Auth APIs

| Method | Path | Access |
|--------|------|--------|
| POST | `/auth/signup` | Public |
| POST | `/auth/login` | Public |
| POST | `/auth/refresh` | Public (refresh token) |
| POST | `/auth/logout` | Authenticated |
| GET | `/auth/profile` | Authenticated |

## Locker APIs

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| GET | `/lockers` | user, admin | List lockers |
| GET | `/lockers/:id` | user, admin | Get locker |
| POST | `/lockers` | admin | Create locker + boxes |
| PUT | `/lockers/:id` | admin | Update locker |
| DELETE | `/lockers/:id` | admin | Delete locker + boxes |

## Box APIs

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| GET | `/boxes` | user, admin | List boxes |
| GET | `/boxes/:id` | user, admin | Get box |
| PUT | `/boxes/:id` | admin | Update box |

## Item APIs

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| GET | `/items` | user, admin | List items |
| GET | `/items/:id` | user, admin | Get item |
| POST | `/items` | admin | Create item |
| PUT | `/items/:id` | admin | Update item |
| DELETE | `/items/:id` | admin | Delete item |

## Stock APIs

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| GET | `/stock` | user, admin | List stock |
| GET | `/stock/:id` | user, admin | Get stock |
| POST | `/stock` | admin | Assign stock to box |
| PUT | `/stock/:id` | admin | Update stock |
| POST | `/stock/:id/restock` | admin | Restock |
| POST | `/stock/:id/move` | admin | Move stock |
| DELETE | `/stock/:id` | admin | Remove stock |

## Cart APIs

Requires user JWT (`authorize('user')`).

| Method | Path | Description |
|--------|------|-------------|
| GET | `/cart` | Get or create active cart |
| POST | `/cart/add` | Add stock item (`stockId`, `quantity`) |
| PUT | `/cart/update` | Update line (`cartItemId`, `quantity`) |
| DELETE | `/cart/remove/:id` | Remove cart line by item `_id` |
| DELETE | `/cart/clear` | Clear all lines |

### Rules

- Cannot mix items from different lockers
- Cannot exceed available stock
- Cannot add disabled items / unavailable stock
- Auto-calculates `subtotal`, GST `tax`, `grandTotal`

## Checkout & Order APIs

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| POST | `/checkout` | user | Create order, reserve stock, payment pending |
| GET | `/orders` | user, admin | List orders (users see own) |
| GET | `/orders/:id` | user, admin | Get order by `_id` or `orderNumber` |
| PUT | `/orders/:id/cancel` | user, admin | Cancel unpaid order + release stock |

### Order statuses

`CREATED` · `WAITING_PAYMENT` · `PAYMENT_SUCCESS` · `READY_FOR_COLLECTION` · `COLLECTED` · `CANCELLED` · `EXPIRED`

### Order payment statuses

`PENDING` · `SUCCESS` · `FAILED` · `REFUNDED`

### Checkout behavior

1. Validates cart + live stock
2. Creates order (`WAITING_PAYMENT`, `paymentStatus=PENDING`)
3. Atomically reserves stock (decrements quantity)
4. Clears cart and opens a new active cart
5. Sets `expiresAt` from `ORDER_RESERVATION_MINUTES` (default 15)
6. Background job auto-expires unpaid orders and releases stock

### Checkout body

```json
{ "discount": 0 }
```

## Payment APIs (Razorpay)

| Method | Path | Roles | Description |
|--------|------|-------|-------------|
| POST | `/payment/create-order` | user | Create Razorpay order for a Campus Essentials order |
| POST | `/payment/verify` | user, admin | Verify Razorpay signature; mark paid |
| POST | `/payment/fail` | user, admin | Mark payment failed + release reserved stock |
| GET | `/payment/:id` | user, admin | Get payment by id |
| GET | `/payments` | user, admin | List payments (users see own) |
| POST | `/payment/:id/refund` | admin | Refund **placeholder** (no gateway refund) |

### Payment flow

```text
Cart → Checkout → Order (WAITING_PAYMENT)
  → POST /payment/create-order  (Razorpay order + Payment PENDING)
  → User pays in Razorpay Checkout (client)
  → POST /payment/verify        (HMAC signature on backend)
  → Payment SUCCESS
  → Order PAYMENT_SUCCESS → READY_FOR_COLLECTION
```

Door opening / BLE radio is **not** implemented on the server. Phase 10 defines the phone↔locker protocol only (see repo `docs/ble-protocol/`).

### Payment statuses

`CREATED` · `PENDING` · `SUCCESS` · `FAILED` · `REFUNDED`

### Payment document fields

`gateway` · `gatewayOrderId` · `gatewayPaymentId` · `signature` · `currency` · `amount` · `paymentMethod` · timestamps

### Business rules

- Create Razorpay order and store `gatewayOrderId`
- Store `gatewayPaymentId` + `signature` only after verify attempt
- **Never trust frontend payment success** — only update order after backend signature verification
- Reject duplicate successful verification (`409`)
- Reject invalid signatures (`400`)
- Reject invalid / unknown Razorpay order IDs (`404`)
- On **fail**: Payment `FAILED`, order `paymentStatus=FAILED`, release reserved stock
- On **refund placeholder**: Payment `REFUNDED` (no Razorpay refund API call)

### Create order body

```json
{ "orderId": "<order _id or orderNumber>" }
```

### Verify body

```json
{
  "razorpay_order_id": "order_...",
  "razorpay_payment_id": "pay_...",
  "razorpay_signature": "<hmac>",
  "paymentMethod": "upi"
}
```

### Fail body

```json
{ "orderId": "<order _id or orderNumber>", "reason": "User cancelled" }
```

### Environment

```bash
# Real Test / Live (Phase 11.9) — official Razorpay Node SDK
RAZORPAY_MOCK=false
RAZORPAY_KEY_ID=rzp_test_xxxxx
RAZORPAY_KEY_SECRET=your_secret

# Offline smoke only:
# RAZORPAY_MOCK=true
```

See `docs/payments/real-razorpay.md` for Test→Live switching, security, and webhooks (future).

Key Secret must never be shipped in Flutter — only Key ID is returned by `POST /payment/create-order`.

### Audit actions

`payment_created` · `payment_verified` · `payment_failed` · `payment_refunded`

## Postman collections

- `postman/Campus_Essentials_Auth.postman_collection.json`
- `postman/Campus_Essentials_Locker_Box.postman_collection.json`
- `postman/Campus_Essentials_Items_Stock.postman_collection.json`
- `postman/Campus_Essentials_Cart_Orders.postman_collection.json`
- `postman/Campus_Essentials_Payments.postman_collection.json`

## BLE protocol (Phase 10)

Protocol design lives outside the Express app (server has **no** BLE link):

| Path | Contents |
|------|----------|
| `docs/ble-protocol/` | Spec, examples, sequence/state diagrams, security, developer guide |
| `protocol/ble/` | Packet model, serializer/parser, checksum placeholder, seq/retry/timeout, state machine |

```bash
# From repo root
node protocol/ble/selfcheck.js
```

## Getting started

```bash
cd server
cp .env.example .env
npm install
npm run dev
```

Requires MongoDB (Atlas or local), JWT secrets, and Razorpay env vars in `.env`.

Smoke / Razorpay tests (server must be running for integration):

```bash
npm test
node tests/phase9.smoke.js
node tests/phase11_9.razorpay.integration.js
```
