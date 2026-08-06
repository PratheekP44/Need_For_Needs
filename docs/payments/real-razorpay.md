# Razorpay TEST MODE integration

Campus Essentials payments use `PaymentService` + `razorpay.client.js`.
Flutter never decides payment success — only `POST /payment/verify` does.
Mock gateway paths have been removed.

## Flow

```
Flutter Pay
  → POST /checkout                 (Mongo order WAITING_PAYMENT; stock NOT reduced)
  → POST /payment/create-order     (Razorpay TEST order; returns keyId + orderId)
  → Razorpay Checkout SDK          (customer pays with test cards/UPI)
  → POST /payment/verify           (HMAC SHA256 on backend)
  → Assign ONE stock record / line (decrement inventory)
  → Issue CE1 collection token
  → Create/update Transaction
  → Broadcast GET /events/inventory (SSE)
  → order.status = READY_FOR_COLLECTION
```

## Configuration (`server/.env` only)

| Variable | Purpose |
|----------|---------|
| `RAZORPAY_KEY_ID` | Test Key ID (`rzp_test_…`) |
| `RAZORPAY_KEY_SECRET` | Matching Key Secret (**backend only**) |

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=your_test_secret
```

- Flutter receives **Key ID only** from `POST /payment/create-order`.
- **Never** embed `RAZORPAY_KEY_SECRET` in the Flutter app.
- Live keys (`rzp_live_*`) are rejected by the server in this build.

## Signature verification

```text
HMAC_SHA256(key=RAZORPAY_KEY_SECRET, body=`${razorpay_order_id}|${razorpay_payment_id}`)
```

Invalid signatures → payment `FAILED`, HTTP 400 (retry allowed without a claimed payment id).
Duplicate successful verify → HTTP 200 idempotent response.

## Real-time inventory

After successful verify, the server publishes on `/events/inventory` (SSE).
Flutter refreshes Home, Cart, Orders, Product/Locker details, and Admin dashboard.
