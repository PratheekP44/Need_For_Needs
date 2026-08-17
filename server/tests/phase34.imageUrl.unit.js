'use strict';

/**
 * Phase 34 — permanent product imageUrl unit tests (no Mongo required).
 */

const assert = require('assert');
const {
  assertPublicImageUrl,
  resolveStoredImageUrl,
  isPrivateOrLocalHostname,
} = require('../src/utils/imageUrl');

/** Local mirror of item.service buildItemUpdates preserve rules (pure). */
function buildItemUpdates(payload, adminId) {
  const UPDATABLE = [
    'itemId',
    'name',
    'description',
    'category',
    'brand',
    'barcode',
    'imageUrl',
    'sellingPrice',
    'costPrice',
    'gstPercentage',
    'unit',
    'isActive',
    'tags',
  ];
  const updates = { updatedBy: adminId || null };
  for (const key of UPDATABLE) {
    if (!Object.prototype.hasOwnProperty.call(payload, key)) continue;
    if (payload[key] === undefined) continue;
    if (key === 'imageUrl') {
      updates.imageUrl = assertPublicImageUrl(payload.imageUrl, {
        allowEmpty: true,
        allowRelativeUploads: true,
      });
      continue;
    }
    updates[key] = payload[key];
  }
  return updates;
}

function testAssertPublic() {
  assert.strictEqual(assertPublicImageUrl(''), '');
  assert.strictEqual(
    assertPublicImageUrl('https://cdn.example.com/a.jpg'),
    'https://cdn.example.com/a.jpg',
  );
  assert.strictEqual(
    assertPublicImageUrl('/uploads/items/x.jpg'),
    '/uploads/items/x.jpg',
  );

  assert.throws(
    () => assertPublicImageUrl('http://192.168.1.10/x.jpg'),
    /publicly accessible/i,
  );
  assert.throws(
    () => assertPublicImageUrl('http://localhost:5000/x.jpg'),
    /publicly accessible/i,
  );
  assert.throws(
    () => assertPublicImageUrl('file:///C:/a.jpg'),
    /publicly accessible/i,
  );
  assert.throws(() => assertPublicImageUrl('not-a-url'), /HTTP\/HTTPS/i);
}

function testPrivateHost() {
  assert.strictEqual(isPrivateOrLocalHostname('localhost'), true);
  assert.strictEqual(isPrivateOrLocalHostname('127.0.0.1'), true);
  assert.strictEqual(isPrivateOrLocalHostname('192.168.0.5'), true);
  assert.strictEqual(isPrivateOrLocalHostname('10.0.0.2'), true);
  assert.strictEqual(isPrivateOrLocalHostname('cdn.example.com'), false);
}

function testResolve() {
  const prev = process.env.PUBLIC_API_BASE_URL;
  process.env.PUBLIC_API_BASE_URL = 'https://need-for-needs.onrender.com';
  assert.strictEqual(
    resolveStoredImageUrl('/uploads/items/a.jpg'),
    'https://need-for-needs.onrender.com/uploads/items/a.jpg',
  );
  assert.strictEqual(
    resolveStoredImageUrl('https://cdn.example.com/b.png'),
    'https://cdn.example.com/b.png',
  );
  assert.strictEqual(resolveStoredImageUrl(''), '');
  if (prev === undefined) delete process.env.PUBLIC_API_BASE_URL;
  else process.env.PUBLIC_API_BASE_URL = prev;
}

function testPreserveSemantics() {
  const withoutImage = buildItemUpdates(
    { name: 'Cable', sellingPrice: 10 },
    'admin1',
  );
  assert.strictEqual(
    Object.prototype.hasOwnProperty.call(withoutImage, 'imageUrl'),
    false,
    'omitted imageUrl must not be written',
  );

  const clearImage = buildItemUpdates({ imageUrl: '' }, 'admin1');
  assert.strictEqual(clearImage.imageUrl, '');

  const setImage = buildItemUpdates(
    { imageUrl: 'https://cdn.example.com/x.jpg' },
    'admin1',
  );
  assert.strictEqual(setImage.imageUrl, 'https://cdn.example.com/x.jpg');
}

function main() {
  testAssertPublic();
  testPrivateHost();
  testResolve();
  testPreserveSemantics();
  console.log('phase34.imageUrl.unit.js OK');
}

main();
