'use strict';

const itemService = require('../services/item.service');
const asyncHandler = require('../middlewares/asyncHandler');
const AppError = require('../utils/AppError');

const listItems = asyncHandler(async (req, res) => {
  const data = await itemService.listItems(req.query);
  res.status(200).json({
    success: true,
    message: 'Items fetched successfully',
    data,
  });
});

const getItem = asyncHandler(async (req, res) => {
  const item = await itemService.getItemById(req.params.id);
  res.status(200).json({
    success: true,
    message: 'Item fetched successfully',
    data: { item },
  });
});

const createItem = asyncHandler(async (req, res) => {
  const item = await itemService.createItem(req.body, req.auth?.sub);
  res.status(201).json({
    success: true,
    message: 'Item created successfully',
    data: { item },
  });
});

const updateItem = asyncHandler(async (req, res) => {
  const item = await itemService.updateItem(req.params.id, req.body, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Item updated successfully',
    data: { item },
  });
});

const deleteItem = asyncHandler(async (req, res) => {
  const result = await itemService.deleteItem(req.params.id, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Item deleted successfully',
    data: result,
  });
});

const uploadItemImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    throw new AppError('Image file is required (field name: image)', 400);
  }
  const item = await itemService.uploadImage(req.params.id, req.file, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Item image uploaded successfully',
    data: { item },
  });
});

const removeItemImage = asyncHandler(async (req, res) => {
  const item = await itemService.removeImage(req.params.id, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Item image removed successfully',
    data: { item },
  });
});

module.exports = {
  listItems,
  getItem,
  createItem,
  updateItem,
  deleteItem,
  uploadItemImage,
  removeItemImage,
};
