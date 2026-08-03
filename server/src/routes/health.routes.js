'use strict';

const express = require('express');
const asyncHandler = require('../middlewares/asyncHandler');

const router = express.Router();

router.get(
  '/',
  asyncHandler(async (req, res) => {
    res.status(200).json({
      success: true,
      message: 'Campus Essentials Backend Running',
    });
  }),
);

module.exports = router;
