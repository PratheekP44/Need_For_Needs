'use strict';

/**
 * Permanent product image URL helpers.
 * Canonical Mongo field: imageUrl (string, preferably absolute https).
 */

function getPublicApiBase() {
  const raw =
    process.env.PUBLIC_API_BASE_URL ||
    process.env.RENDER_EXTERNAL_URL ||
    process.env.API_PUBLIC_URL ||
    '';
  return String(raw).trim().replace(/\/+$/, '');
}

function isPrivateOrLocalHostname(hostname) {
  const host = String(hostname || '')
    .trim()
    .toLowerCase()
    .replace(/\.+$/, '');
  if (!host) return true;
  if (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '0.0.0.0' ||
    host === '::1' ||
    host === '[::1]' ||
    host.endsWith('.local')
  ) {
    return true;
  }
  // IPv4 private / link-local
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (ipv4) {
    const a = Number(ipv4[1]);
    const b = Number(ipv4[2]);
    if (a === 10) return true;
    if (a === 127) return true;
    if (a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 192 && b === 168) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
  }
  return false;
}

/**
 * Validate admin-supplied imageUrl.
 * @param {unknown} value
 * @param {{ allowEmpty?: boolean, allowRelativeUploads?: boolean }} [opts]
 * @returns {string} normalized value (trimmed) or ''
 * @throws {Error} with user-facing message
 */
function assertPublicImageUrl(value, opts = {}) {
  const allowEmpty = opts.allowEmpty !== false;
  const allowRelativeUploads = opts.allowRelativeUploads !== false;

  if (value === undefined || value === null) {
    if (allowEmpty) return '';
    throw new Error('imageUrl is required');
  }
  if (typeof value !== 'string') {
    throw new Error('imageUrl must be a string');
  }
  const trimmed = value.trim();
  if (!trimmed) {
    if (allowEmpty) return '';
    throw new Error('imageUrl is required');
  }
  if (trimmed.length > 1000) {
    throw new Error('Image URL cannot exceed 1000 characters');
  }
  if (/^(file:|content:|data:)/i.test(trimmed)) {
    throw new Error('This image URL must be publicly accessible.');
  }
  if (allowRelativeUploads && trimmed.startsWith('/uploads/')) {
    return trimmed;
  }

  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error('imageUrl must be a valid HTTP/HTTPS URL');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new Error('imageUrl must be a valid HTTP/HTTPS URL');
  }
  if (!parsed.hostname) {
    throw new Error('imageUrl must be a valid HTTP/HTTPS URL');
  }
  if (isPrivateOrLocalHostname(parsed.hostname)) {
    throw new Error('This image URL must be publicly accessible.');
  }
  return trimmed;
}

/**
 * Absolutize relative /uploads paths for API responses (and optional storage).
 * Absolute http(s) URLs are returned unchanged.
 */
function resolveStoredImageUrl(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith('/uploads/')) {
    const base = getPublicApiBase();
    return base ? `${base}${value}` : value;
  }
  return value;
}

/**
 * Prefer storing an absolute URL for uploads when PUBLIC_API_BASE_URL is set.
 */
function toPersistentImageUrl(publicOrRelative) {
  return resolveStoredImageUrl(publicOrRelative);
}

module.exports = {
  getPublicApiBase,
  isPrivateOrLocalHostname,
  assertPublicImageUrl,
  resolveStoredImageUrl,
  toPersistentImageUrl,
};
