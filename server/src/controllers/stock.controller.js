'use strict';

const stockService = require('../services/stock.service');
const asyncHandler = require('../middlewares/asyncHandler');

const listStock = asyncHandler(async (req, res) => {
  const data = await stockService.listStock(req.query);
  res.status(200).json({
    success: true,
    message: 'Stock fetched successfully',
    data,
  });
});

const getStock = asyncHandler(async (req, res) => {
  const stock = await stockService.getStockById(req.params.id);
  res.status(200).json({
    success: true,
    message: 'Stock fetched successfully',
    data: { stock },
  });
});

const createStock = asyncHandler(async (req, res) => {
  const stock = await stockService.assignStock(req.body, req.auth?.sub);
  res.status(201).json({
    success: true,
    message: 'Stock assigned to box successfully',
    data: { stock },
  });
});

const createStockBatch = asyncHandler(async (req, res) => {
  const data = await stockService.assignStockBatch(req.body, req.auth?.sub);
  res.status(201).json({
    success: true,
    message: `Assigned ${data.count} unit(s) to ${data.count} box(es)`,
    data,
  });
});

const updateStock = asyncHandler(async (req, res) => {
  const stock = await stockService.updateStock(req.params.id, req.body, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Stock updated successfully',
    data: { stock },
  });
});

const deleteStock = asyncHandler(async (req, res) => {
  const result = await stockService.removeStock(req.params.id, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Stock removed from box successfully',
    data: result,
  });
});

const restock = asyncHandler(async (req, res) => {
  const stock = await stockService.restock(req.params.id, req.body, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Stock restocked successfully',
    data: { stock },
  });
});

const moveStock = asyncHandler(async (req, res) => {
  const stock = await stockService.moveStock(req.params.id, req.body, req.auth?.sub);
  res.status(200).json({
    success: true,
    message: 'Stock moved successfully',
    data: { stock },
  });
});

module.exports = {
  listStock,
  getStock,
  createStock,
  createStockBatch,
  updateStock,
  deleteStock,
  restock,
  moveStock,
};
