'use strict';

const catalogService = require('../services/catalog.service');
const asyncHandler = require('../middlewares/asyncHandler');

const getHome = asyncHandler(async (req, res) => {
  const data = await catalogService.getHomeFeed(req.query);
  if (req.auth?.role === 'user' || req.auth?.accountType === 'user') {
    const buyAgain = await catalogService.getBuyAgain(req.auth.sub, 8);
    data.sections.push({
      key: 'recent',
      title: 'Buy again',
      items: buyAgain.items,
    });
  }
  res.status(200).json({
    success: true,
    message: 'Home catalog fetched successfully',
    data,
  });
});

const listCategories = asyncHandler(async (_req, res) => {
  const data = await catalogService.listCategories();
  res.status(200).json({
    success: true,
    message: 'Categories fetched successfully',
    data,
  });
});

module.exports = {
  getHome,
  listCategories,
};
