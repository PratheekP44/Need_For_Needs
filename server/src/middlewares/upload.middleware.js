'use strict';

const multer = require('multer');
const path = require('path');
const AppError = require('../utils/AppError');

const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5 MB
  },
  fileFilter: (_req, file, cb) => {
    if (ALLOWED_MIME.has(file.mimetype)) {
      cb(null, true);
      return;
    }
    // Some browsers / Flutter clients send octet-stream; accept by extension.
    const ext = path.extname(file.originalname || '').toLowerCase();
    const allowedExt = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif']);
    const looseMime =
      !file.mimetype ||
      file.mimetype === 'application/octet-stream' ||
      file.mimetype === 'binary/octet-stream';
    if (looseMime && allowedExt.has(ext)) {
      cb(null, true);
      return;
    }
    cb(new AppError('Only JPEG, PNG, WebP, or GIF images are allowed', 400));
  },
});

/**
 * Single image field named "image".
 */
const uploadItemImage = upload.single('image');

function handleMulterError(err, _req, _res, next) {
  if (!err) {
    next();
    return;
  }
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      next(new AppError('Image must be 5MB or smaller', 400));
      return;
    }
    next(new AppError(err.message, 400));
    return;
  }
  next(err);
}

module.exports = {
  uploadItemImage,
  handleMulterError,
  ALLOWED_MIME,
};
