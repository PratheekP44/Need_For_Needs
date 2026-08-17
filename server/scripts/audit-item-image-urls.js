'use strict';

/**
 * Phase 34 — audit + optionally normalize item imageUrl values in MongoDB.
 *
 * Usage:
 *   node scripts/audit-item-image-urls.js
 *   node scripts/audit-item-image-urls.js --normalize
 *
 * --normalize absolutizes relative /uploads/... paths when PUBLIC_API_BASE_URL
 * is set. Does not delete legacy data.
 */

require('../src/config/env').loadEnv();
const mongoose = require('mongoose');
const Item = require('../src/models/Item');
const {
  resolveStoredImageUrl,
  isPrivateOrLocalHostname,
} = require('../src/utils/imageUrl');

async function main() {
  const normalize = process.argv.includes('--normalize');
  await mongoose.connect(process.env.MONGODB_URI);

  const items = await Item.find({}).select('itemId name imageUrl').lean();
  let withUrl = 0;
  let missing = 0;
  let relativeUploads = 0;
  let absoluteHttp = 0;
  let privateOrLocal = 0;
  let legacyOther = 0;
  let normalized = 0;

  for (const item of items) {
    const raw = String(item.imageUrl || '').trim();
    if (!raw) {
      missing += 1;
      continue;
    }
    withUrl += 1;
    if (raw.startsWith('/uploads/')) {
      relativeUploads += 1;
      if (normalize) {
        const next = resolveStoredImageUrl(raw);
        if (next && next !== raw) {
          await Item.updateOne({ _id: item._id }, { $set: { imageUrl: next } });
          normalized += 1;
        }
      }
    } else if (/^https?:\/\//i.test(raw)) {
      absoluteHttp += 1;
      try {
        const host = new URL(raw).hostname;
        if (isPrivateOrLocalHostname(host)) privateOrLocal += 1;
      } catch (_) {
        legacyOther += 1;
      }
    } else {
      legacyOther += 1;
    }
  }

  // Detect accidental non-imageUrl fields on documents (shouldn't exist).
  const sample = await Item.collection.findOne({
    $or: [
      { image: { $exists: true } },
      { image_url: { $exists: true } },
      { imagePath: { $exists: true } },
      { photo: { $exists: true } },
    ],
  });

  console.log(
    JSON.stringify(
      {
        totalItems: items.length,
        withImageUrl: withUrl,
        missingImageUrl: missing,
        relativeUploads,
        absoluteHttp,
        privateOrLocalHttp: privateOrLocal,
        otherLegacyStyleValues: legacyOther,
        documentsWithLegacyImageKeys: sample ? 1 : 0,
        normalizedToAbsolute: normalized,
        publicApiBase:
          process.env.PUBLIC_API_BASE_URL ||
          process.env.RENDER_EXTERNAL_URL ||
          null,
      },
      null,
      2,
    ),
  );

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
