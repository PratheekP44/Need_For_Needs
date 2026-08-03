'use strict';

const fs = require('fs');
const path = require('path');

const LOG_DIR = path.resolve(__dirname, '../logs');

const LEVELS = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

function ensureLogDir() {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
}

function timestamp() {
  return new Date().toISOString();
}

function shouldLog(level) {
  const configured = (process.env.LOG_LEVEL || 'info').toLowerCase();
  const current = LEVELS[configured] ?? LEVELS.info;
  const incoming = LEVELS[level] ?? LEVELS.info;
  return incoming <= current;
}

function writeToFile(line) {
  try {
    ensureLogDir();
    const file = path.join(LOG_DIR, 'app.log');
    fs.appendFileSync(file, `${line}\n`, 'utf8');
  } catch {
    // File logging must never crash the process.
  }
}

function format(level, message, meta) {
  const base = `[${timestamp()}] ${level.toUpperCase()}: ${message}`;
  if (meta === undefined) {
    return base;
  }
  return `${base} ${typeof meta === 'string' ? meta : JSON.stringify(meta)}`;
}

function log(level, message, meta) {
  if (!shouldLog(level)) {
    return;
  }

  const line = format(level, message, meta);

  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    console.log(line);
  }

  writeToFile(line);
}

const logger = {
  error: (message, meta) => log('error', message, meta),
  warn: (message, meta) => log('warn', message, meta),
  info: (message, meta) => log('info', message, meta),
  http: (message, meta) => log('http', message, meta),
  debug: (message, meta) => log('debug', message, meta),
  stream: {
    write: (message) => {
      logger.http(message.trim());
    },
  },
};

module.exports = logger;
