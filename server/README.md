# Campus Essentials Backend

Node.js + Express architecture for the Campus Essentials (Need For Needs) smart locker platform.

## Phase

**Phase 3 — Backend architecture only**

This module does **not** include:

- Business logic
- MongoDB schemas / models
- Authentication
- Payment (Razorpay)
- BLE integrations
- Feature APIs (beyond health)

## Stack

- Node.js
- Express.js
- Mongoose (installed & configured for later phases)
- dotenv, helmet, cors, morgan, compression, cookie-parser
- express-rate-limit, express-validator
- nodemon (development)

## Folder structure

```text
server/
├── app.js
├── server.js
├── package.json
├── .env.example
├── .gitignore
├── README.md
├── src/
│   ├── config/
│   ├── controllers/
│   ├── middlewares/
│   ├── models/
│   ├── repositories/
│   ├── routes/
│   ├── services/
│   ├── database/
│   ├── validators/
│   ├── utils/
│   ├── logs/
│   └── uploads/
└── tests/
```

## Getting started

```bash
cd server
cp .env.example .env
npm install
npm run dev
```

Production-style start:

```bash
npm run start
```

## Health check

```http
GET /health
```

Response:

```json
{
  "success": true,
  "message": "Campus Essentials Backend Running"
}
```

Default port: `5000` (override with `PORT` in `.env`).
