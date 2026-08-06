'use strict';

const lockerService = require('../services/locker.service');
const asyncHandler = require('../middlewares/asyncHandler');

const listLockers = asyncHandler(async (req, res) => {
  const data = await lockerService.listLockers(req.query);
  res.status(200).json({
    success: true,
    message: 'Lockers fetched successfully',
    data,
  });
});

const getLocker = asyncHandler(async (req, res) => {
  const locker = await lockerService.getLockerById(req.params.id, req.query);
  res.status(200).json({
    success: true,
    message: 'Locker fetched successfully',
    data: { locker },
  });
});

const createLocker = asyncHandler(async (req, res) => {
  const locker = await lockerService.createLocker(req.body);
  res.status(201).json({
    success: true,
    message: 'Locker created successfully',
    data: { locker },
  });
});

const updateLocker = asyncHandler(async (req, res) => {
  const locker = await lockerService.updateLocker(req.params.id, req.body);
  res.status(200).json({
    success: true,
    message: 'Locker updated successfully',
    data: { locker },
  });
});

const deleteLocker = asyncHandler(async (req, res) => {
  const result = await lockerService.deleteLocker(req.params.id);
  res.status(200).json({
    success: true,
    message: 'Locker deleted successfully',
    data: result,
  });
});

module.exports = {
  listLockers,
  getLocker,
  createLocker,
  updateLocker,
  deleteLocker,
};
