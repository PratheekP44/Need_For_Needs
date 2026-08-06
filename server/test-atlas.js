'use strict';

/**
 * Standalone Atlas connectivity test.
 * Uses the same server/.env MONGODB_URI as the application.
 *
 * Usage (from server/):
 *   node test-atlas.js
 */

const path = require('path');
const dns = require('dns');
const dotenv = require('dotenv');
const mongoose = require('mongoose');

const envPath = path.resolve(__dirname, '.env');
dotenv.config({ path: envPath, quiet: true });

function maskMongoUri(uri) {
  return String(uri).replace(/\/\/([^:/@]+):([^@]+)@/, '//$1:***@');
}

function sanitizeMongoUri(uri) {
  return String(uri || '')
    .trim()
    .replace(/^['"]|['"]$/g, '');
}

async function tryConnect(label, uri) {
  console.log(`\n[${label}] Connecting to ${maskMongoUri(uri)}`);
  console.log(`[${label}] DNS servers: ${dns.getServers().join(', ')}`);

  try {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
    console.log(
      `[${label}] SUCCESS host=${mongoose.connection.host} db=${mongoose.connection.name}`,
    );
    await mongoose.disconnect();
    return true;
  } catch (error) {
    console.log(`[${label}] FAIL ${error.message}`);
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect().catch(() => {});
    }
    return false;
  }
}

async function main() {
  const raw = process.env.MONGODB_URI;
  const uri = sanitizeMongoUri(raw);

  console.log('env file:', envPath);
  console.log('MONGODB_URI set:', Boolean(raw));
  console.log('MONGODB_URI masked:', maskMongoUri(uri || '(empty)'));
  console.log('Initial DNS servers:', dns.getServers().join(', '));

  if (!uri) {
    console.error('MONGODB_URI is missing from .env');
    process.exit(1);
  }

  // Attempt 1: as configured
  let ok = await tryConnect('attempt-1-default-dns', uri);

  // Attempt 2: public DNS (fixes Windows querySrv ECONNREFUSED with 127.0.0.1)
  if (!ok && uri.startsWith('mongodb+srv://')) {
    dns.setServers(['8.8.8.8', '1.1.1.1']);
    ok = await tryConnect('attempt-2-public-dns', uri);
  }

  // Attempt 3: optional standard URI override for manual testing
  const standardUri = sanitizeMongoUri(process.env.MONGODB_STANDARD_URI || '');
  if (!ok && standardUri.startsWith('mongodb://')) {
    ok = await tryConnect('attempt-3-standard-uri', standardUri);
  }

  if (!ok) {
    console.error('\nAll Atlas connection attempts failed.');
    process.exit(1);
  }

  console.log('\nAtlas connectivity OK');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
