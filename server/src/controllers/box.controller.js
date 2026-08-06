'use strict';

const boxService = require('../services/box.service');
const asyncHandler = require('../middlewares/asyncHandler');

const listBoxes = asyncHandler(async (req, res) => {
  const data = await boxService.listBoxes(req.query);
  res.status(200).json({
    success: true,
    message: 'Boxes fetched successfully',
    data,
  });
});

const getBox = asyncHandler(async (req, res) => {
  const box = await boxService.getBoxById(req.params.id);
  res.status(200).json({
    success: true,
    message: 'Box fetched successfully',
    data: { box },
  });
});

const updateBox = asyncHandler(async (req, res) => {
  const box = await boxService.updateBox(req.params.id, req.body);
  res.status(200).json({
    success: true,
    message: 'Box updated successfully',
    data: { box },
  });
});

module.exports = {
  listBoxes,
  getBox,
  updateBox,
};
