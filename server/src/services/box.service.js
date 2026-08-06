'use strict';

const mongoose = require('mongoose');
const boxRepository = require('../repositories/box.repository');
const Stock = require('../models/Stock');
const AppError = require('../utils/AppError');
const { parseListQuery, buildPagination } = require('../utils/query');
const { buildBoxPayload } = require('./locker.service');

class BoxService {
  formatBox(box) {
    const payload = buildBoxPayload(box);
    if (box.locker && typeof box.locker === 'object') {
      payload.locker = {
        id: box.locker._id || box.locker.id,
        lockerId: box.locker.lockerId,
        lockerName: box.locker.lockerName,
        status: box.locker.status,
      };
    } else {
      payload.locker = box.locker;
    }
    return payload;
  }

  async listBoxes(query) {
    const listQuery = parseListQuery(query, {
      defaultSort: 'boxNumber',
      allowedSortFields: [
        'boxNumber',
        'createdAt',
        'updatedAt',
        'status',
        'doorState',
        'boxId',
      ],
      filterFields: {
        status: 'status',
        doorState: 'doorState',
        isEmpty: 'isEmpty',
        locker: 'locker',
        boxId: 'boxId',
      },
      searchFields: ['boxId'],
    });

    if (listQuery.filter.boxId) {
      listQuery.filter.boxId = String(listQuery.filter.boxId).toUpperCase();
    }

    if (listQuery.filter.isEmpty !== undefined) {
      const value = String(listQuery.filter.isEmpty).toLowerCase();
      listQuery.filter.isEmpty = value === 'true' || value === '1';
    }

    if (listQuery.filter.locker) {
      if (!mongoose.isValidObjectId(listQuery.filter.locker)) {
        throw new AppError('Invalid locker filter. Use locker ObjectId.', 400);
      }
    }

    // Only boxes with no Stock record (one box → one stock).
    const unassigned =
      query.unassigned === 'true' ||
      query.unassigned === '1' ||
      query.availableForStock === 'true' ||
      query.availableForStock === '1';

    if (unassigned) {
      const stockFilter = {};
      if (listQuery.filter.locker) {
        stockFilter.locker = listQuery.filter.locker;
      }
      const occupiedBoxIds = await Stock.distinct('box', stockFilter);
      listQuery.filter._id = { $nin: occupiedBoxIds };
      listQuery.filter.status = {
        $nin: ['MAINTENANCE', 'FAULT', 'RESERVED'],
      };
    }

    const { items, total } = await boxRepository.list(listQuery);

    return {
      boxes: items.map((box) => this.formatBox(box)),
      pagination: buildPagination({
        page: listQuery.page,
        limit: listQuery.limit,
        total,
      }),
    };
  }

  async getBoxById(id) {
    const box = await boxRepository.findByIdOrBoxId(id);
    if (!box) {
      throw new AppError('Box not found', 404);
    }
    return this.formatBox(box);
  }

  async updateBox(id, payload) {
    const box = await boxRepository.findByIdOrBoxId(id);
    if (!box) {
      throw new AppError('Box not found', 404);
    }

    const updates = {};

    if (payload.status !== undefined) {
      updates.status = payload.status;
      updates.isEmpty = payload.status === 'EMPTY'
        ? true
        : payload.isEmpty !== undefined
          ? payload.isEmpty
          : box.isEmpty;
    }

    if (payload.isEmpty !== undefined && payload.status === undefined) {
      updates.isEmpty = payload.isEmpty;
      if (payload.isEmpty === true) {
        updates.status = 'EMPTY';
      }
    }

    if (payload.doorState !== undefined) {
      updates.doorState = payload.doorState;
      if (payload.doorState === 'OPEN') {
        updates.lastOpened = new Date();
      }
    }

    if (payload.lastOpened !== undefined) {
      updates.lastOpened = payload.lastOpened;
    }

    const updated = await boxRepository.updateById(box._id, updates);
    if (!updated) {
      throw new AppError('Box not found', 404);
    }

    return this.formatBox(updated);
  }
}

module.exports = new BoxService();
