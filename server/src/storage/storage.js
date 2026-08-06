'use strict';

/**
 * Replaceable object-storage abstraction.
 * LocalFileStorage is the default for development.
 * Swap `getStorage()` later for S3 / GCS / Azure without touching controllers.
 */

const path = require('path');
const fs = require('fs/promises');
const crypto = require('crypto');

class LocalFileStorage {
  /**
   * @param {{ rootDir: string, publicBasePath?: string }} options
   */
  constructor(options) {
    this.rootDir = options.rootDir;
    this.publicBasePath = options.publicBasePath || '/uploads';
  }

  async ensureReady() {
    await fs.mkdir(this.rootDir, { recursive: true });
  }

  /**
   * @param {{ buffer: Buffer, originalName: string, mimeType?: string, folder?: string }} input
   * @returns {Promise<{ relativePath: string, publicUrl: string, absolutePath: string }>}
   */
  async save(input) {
    await this.ensureReady();
    const folder = String(input.folder || 'misc').replace(/[^a-zA-Z0-9_-]/g, '');
    const ext = path.extname(input.originalName || '').toLowerCase() || '.bin';
    const safeExt = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].includes(ext)
      ? ext
      : '.jpg';
    const fileName = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${safeExt}`;
    const relativePath = path.posix.join(folder, fileName);
    const absolutePath = path.join(this.rootDir, folder, fileName);

    await fs.mkdir(path.dirname(absolutePath), { recursive: true });
    await fs.writeFile(absolutePath, input.buffer);

    return {
      relativePath,
      publicUrl: `${this.publicBasePath}/${relativePath}`.replace(/\/{2,}/g, '/'),
      absolutePath,
    };
  }

  /**
   * Deletes a previously saved public URL or relative path.
   * Ignores missing files and non-local URLs.
   */
  async delete(publicUrlOrRelative) {
    if (!publicUrlOrRelative) return;
    const value = String(publicUrlOrRelative);
    if (value.startsWith('http://') || value.startsWith('https://')) {
      // External / cloud URL — local provider has nothing to delete.
      if (!value.includes(this.publicBasePath)) return;
    }

    let relative = value;
    const marker = this.publicBasePath.endsWith('/')
      ? this.publicBasePath
      : `${this.publicBasePath}/`;
    const idx = value.indexOf(marker);
    if (idx >= 0) {
      relative = value.slice(idx + marker.length);
    } else if (value.startsWith('/')) {
      relative = value.replace(/^\/uploads\//, '');
    }

    relative = relative.replace(/^[/\\]+/, '');
    if (!relative || relative.includes('..')) return;

    const absolutePath = path.join(this.rootDir, relative);
    try {
      await fs.unlink(absolutePath);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
}

let singleton = null;

function getStorage() {
  if (!singleton) {
    singleton = new LocalFileStorage({
      rootDir: path.join(process.cwd(), 'uploads'),
      publicBasePath: '/uploads',
    });
  }
  return singleton;
}

/**
 * Inject a custom storage provider (tests / cloud).
 * @param {LocalFileStorage} provider
 */
function setStorage(provider) {
  singleton = provider;
}

module.exports = {
  LocalFileStorage,
  getStorage,
  setStorage,
};
