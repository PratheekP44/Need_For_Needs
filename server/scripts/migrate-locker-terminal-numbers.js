'use strict';

/**
 * Backfill Locker.terminalNumber for existing lockers.
 *
 * Schema now requires terminalNumber (1–255). Existing lockers without it
 * cannot issue Unlock JWTs until this runs (or an admin sets the value).
 *
 * Default strategy (no args):
 *   Assign sequential terminal numbers 1..N by createdAt ascending.
 *   VERIFY these match your six physical controllers before production unlock.
 *
 * Explicit mapping:
 *   node scripts/migrate-locker-terminal-numbers.js --map=LCK-01:1,LCK-02:2
 *
 * Dry run:
 *   node scripts/migrate-locker-terminal-numbers.js --dry-run
 */

const { loadEnv } = require('../src/config/env');
const logger = require('../src/config/logger');
const {
  connectDatabase,
  disconnectDatabase,
} = require('../src/database/connection');
const Locker = require('../src/models/Locker');

function parseArgs(argv) {
  const dryRun = argv.includes('--dry-run');
  const mapArg = argv.find((a) => a.startsWith('--map='));
  /** @type {Map<string, number>} */
  const explicit = new Map();
  if (mapArg) {
    const raw = mapArg.slice('--map='.length);
    for (const part of raw.split(',')) {
      const [lockerId, terminal] = part.split(':').map((s) => s.trim());
      const n = Number(terminal);
      if (!lockerId || !Number.isInteger(n) || n < 1 || n > 255) {
        throw new Error(
          `Invalid --map entry "${part}". Expected LOCKER_ID:1-255`,
        );
      }
      explicit.set(lockerId.toUpperCase(), n);
    }
  }
  return { dryRun, explicit };
}

async function main() {
  const { dryRun, explicit } = parseArgs(process.argv.slice(2));
  const config = loadEnv();
  await connectDatabase(config.mongoUri);

  const lockers = await Locker.find({})
    .sort({ createdAt: 1 })
    .select('lockerId terminalNumber createdAt')
    .lean();

  logger.info(`Found ${lockers.length} locker(s)`);

  const used = new Set(
    lockers
      .map((l) => l.terminalNumber)
      .filter((n) => Number.isInteger(n) && n >= 1 && n <= 255),
  );

  let nextAuto = 1;
  const takeNextFree = () => {
    while (used.has(nextAuto) && nextAuto <= 255) nextAuto += 1;
    if (nextAuto > 255) {
      throw new Error('No free terminalNumber left in range 1–255');
    }
    const value = nextAuto;
    used.add(value);
    nextAuto += 1;
    return value;
  };

  let updated = 0;
  let skipped = 0;

  for (const locker of lockers) {
    if (
      Number.isInteger(locker.terminalNumber) &&
      locker.terminalNumber >= 1 &&
      locker.terminalNumber <= 255
    ) {
      skipped += 1;
      logger.info(
        `Skip ${locker.lockerId}: already has terminalNumber=${locker.terminalNumber}`,
      );
      continue;
    }

    let terminalNumber;
    if (explicit.has(locker.lockerId)) {
      terminalNumber = explicit.get(locker.lockerId);
      if (used.has(terminalNumber) && locker.terminalNumber !== terminalNumber) {
        throw new Error(
          `terminalNumber ${terminalNumber} already used (conflict for ${locker.lockerId})`,
        );
      }
      used.add(terminalNumber);
    } else if (explicit.size > 0) {
      throw new Error(
        `No --map entry for ${locker.lockerId}. Provide all lockers or omit --map.`,
      );
    } else {
      terminalNumber = takeNextFree();
    }

    logger.info(
      `${dryRun ? '[dry-run] Would set' : 'Setting'} ${locker.lockerId} → terminalNumber=${terminalNumber}`,
    );

    if (!dryRun) {
      await Locker.updateOne(
        { _id: locker._id },
        { $set: { terminalNumber } },
      );
    }
    updated += 1;
  }

  // Ensure unique index exists (matches schema).
  if (!dryRun) {
    try {
      await Locker.collection.createIndex(
        { terminalNumber: 1 },
        { unique: true, name: 'terminalNumber_1' },
      );
      logger.info('Ensured unique index on terminalNumber');
    } catch (error) {
      logger.warn('Index create skipped/failed', { message: error.message });
    }
  }

  logger.info(
    `Done. ${dryRun ? 'Would update' : 'Updated'}=${updated}, skipped=${skipped}`,
  );
  await disconnectDatabase();
}

main().catch(async (error) => {
  logger.error('Migration failed', { message: error.message, stack: error.stack });
  try {
    await disconnectDatabase();
  } catch (_) {
    // ignore
  }
  process.exit(1);
});
