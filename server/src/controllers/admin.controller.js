'use strict';

const adminService = require('../services/admin.service');
const asyncHandler = require('../middlewares/asyncHandler');

const getStats = asyncHandler(async (_req, res) => {
  const stats = await adminService.getDashboardStats();
  res.status(200).json({
    success: true,
    message: 'Admin stats fetched successfully',
    data: { stats },
  });
});

module.exports = {
  getStats,
};
