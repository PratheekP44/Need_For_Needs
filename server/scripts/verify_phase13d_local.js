'use strict';

/**
 * Local verification: uploads static serve + cart remove id handling.
 */
const path = require('path');
const fs = require('fs');
const http = require('http');
const { loadEnv } = require('../src/config/env');
const createApp = require('../app');
const { getStorage, resolveUploadsRoot } = require('../src/storage/storage');
const { formatCart } = require('../src/services/cart.service');
const mongoose = require('mongoose');

function request(server, method, urlPath, { token, body } = {}) {
  const payload = body ? JSON.stringify(body) : null;
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: server.address().port,
        path: urlPath,
        method,
        headers: {
          Accept: 'application/json',
          ...(payload ? { 'Content-Type': 'application/json' } : {}),
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const raw = Buffer.concat(chunks);
          let json = {};
          try {
            json = raw.length ? JSON.parse(raw.toString('utf8')) : {};
          } catch {
            json = { raw: raw.toString('utf8') };
          }
          resolve({ status: res.statusCode, headers: res.headers, json, raw });
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

(async () => {
  // 1) formatCart always stringifies line ids
  const fake = formatCart({
    _id: new mongoose.Types.ObjectId(),
    cartId: 'CART-TEST',
    user: new mongoose.Types.ObjectId(),
    status: 'ACTIVE',
    subtotal: 10,
    discount: 0,
    tax: 0,
    grandTotal: 10,
    items: [
      {
        _id: new mongoose.Types.ObjectId(),
        quantity: 1,
        priceAtPurchase: 10,
        gstPercentage: 0,
        subtotal: 10,
        item: null,
        stock: null,
        locker: null,
        box: null,
      },
    ],
  });
  assert(typeof fake.items[0].id === 'string', 'cart line id must be string');
  assert(fake.items[0].id.length === 24, 'cart line id must be ObjectId hex');
  console.log('formatCart_id_ok', fake.items[0].id);

  // 2) Static uploads serve a written file
  const config = loadEnv();
  const app = createApp(config);
  await getStorage().ensureReady();
  const root = resolveUploadsRoot();
  const rel = path.join('items', `probe-${Date.now()}.jpg`);
  const abs = path.join(root, rel);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  // Minimal JPEG (1x1)
  const jpeg = Buffer.from(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBxISEhUQEhIVFhUVFRUVFRUVFRUWFxUXFhUYHSggGBolGxUVITEhJSkrLi4uFx8zODMtNygtLisBCgoKDg0OGxAQGy0lHyUtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLf/AABEIAAEAAQMBIgACEQEDEQH/xAAbAAACAwEBAQAAAAAAAAAAAAADBAECBQYAB//EABQBAQAAAAAAAAAAAAAAAAAAAAD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGmP//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAQUCf//EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQMBAT8Bf//EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQIBAT8Bf//Z',
    'base64',
  );
  fs.writeFileSync(abs, jpeg);

  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });

  const img = await request(server, 'GET', `/uploads/${rel.replace(/\\/g, '/')}`);
  assert(img.status === 200, `expected 200 for upload, got ${img.status}`);
  assert(
    String(img.headers['content-type'] || '').includes('image'),
    `expected image content-type, got ${img.headers['content-type']}`,
  );
  console.log('static_uploads_ok', img.status, img.headers['content-type']);

  // 3) resolveMediaUrl parity (Node-side mirror of Flutter rules)
  function resolveMediaUrl(raw, base) {
    const pathVal = String(raw || '').trim();
    if (!pathVal) return '';
    if (pathVal.startsWith('http://') || pathVal.startsWith('https://')) return pathVal;
    const b = String(base).replace(/\/$/, '');
    return pathVal.startsWith('/') ? `${b}${pathVal}` : `${b}/${pathVal}`;
  }
  assert(
    resolveMediaUrl('/uploads/items/a.jpg', 'https://need-for-needs.onrender.com') ===
      'https://need-for-needs.onrender.com/uploads/items/a.jpg',
    'resolver prepend failed',
  );
  assert(
    resolveMediaUrl('https://cdn.example/x.jpg', 'https://need-for-needs.onrender.com') ===
      'https://cdn.example/x.jpg',
    'resolver must keep absolute urls',
  );
  console.log('resolveMediaUrl_ok');

  fs.unlinkSync(abs);
  server.close();
  console.log('phase13d_local_verify_ok');
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
