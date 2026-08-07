'use strict';

const lockerRepository = require('../repositories/locker.repository');
const boxRepository = require('../repositories/box.repository');
const Stock = require('../models/Stock');
const AppError = require('../utils/AppError');
const { parseListQuery, buildPagination } = require('../utils/query');
const { withDistance, parseOrigin } = require('./distance.service');

function buildBoxPayload(box) {
  return {
    id: box._id || box.id,
    boxId: box.boxId,
    boxNumber: box.boxNumber,
    status: box.status,
    doorState: box.doorState,
    isEmpty: box.isEmpty,
    lastOpened: box.lastOpened,
    createdAt: box.createdAt,
    updatedAt: box.updatedAt,
  };
}

function buildLockerPayload(locker, boxes = [], origin = null, extras = {}) {
  const base = typeof locker.toPublicObject === 'function'
    ? locker.toPublicObject()
    : {
        id: locker._id,
        lockerId: locker.lockerId,
        lockerName: locker.lockerName,
        latitude: locker.latitude,
        longitude: locker.longitude,
        BLEDevice: locker.BLEDevice,
        terminalNumber: locker.terminalNumber,
        status: locker.status,
        totalBoxes: locker.totalBoxes,
        description: locker.description,
        createdAt: locker.createdAt,
        updatedAt: locker.updatedAt,
      };

  const emptyBoxes = boxes.filter((b) => b.isEmpty || b.status === 'EMPTY').length;
  const occupiedBoxes = boxes.length - emptyBoxes;

  return withDistance(
    {
      ...base,
      boxes: boxes.map((box) => buildBoxPayload(box)),
      emptyBoxes,
      occupiedBoxes,
      availableBoxes: boxes.filter((b) => b.status === 'AVAILABLE' || b.status === 'EMPTY').length,
      availableItems: extras.availableItems ?? 0,
    },
    origin,
  );
}

function buildBoxSeed(locker, boxNumber) {
  return {
    boxId: `${locker.lockerId}-B${String(boxNumber).padStart(2, '0')}`,
    locker: locker._id,
    boxNumber,
    status: 'EMPTY',
    isEmpty: true,
    doorState: 'CLOSED',
    lastOpened: null,
  };
}

class LockerService {
  async createLocker(payload) {
    const lockerId = String(payload.lockerId).trim().toUpperCase();

    if (await lockerRepository.existsByLockerId(lockerId)) {
      throw new AppError('Locker ID already exists', 409);
    }

    const terminalNumber = Number(payload.terminalNumber);
    if (
      !Number.isInteger(terminalNumber) ||
      terminalNumber < 1 ||
      terminalNumber > 255
    ) {
      throw new AppError('terminalNumber must be an integer between 1 and 255', 400);
    }
    if (await lockerRepository.existsByTerminalNumber(terminalNumber)) {
      throw new AppError('Terminal number already assigned to another locker', 409);
    }

    const locker = await lockerRepository.create({
      lockerId,
      lockerName: payload.lockerName,
      latitude: payload.latitude,
      longitude: payload.longitude,
      BLEDevice: payload.BLEDevice || null,
      terminalNumber,
      status: payload.status || 'OFFLINE',
      totalBoxes: payload.totalBoxes,
      description: payload.description || '',
    });

    const seeds = Array.from({ length: locker.totalBoxes }, (_, index) =>
      buildBoxSeed(locker, index + 1),
    );
    const boxes = await boxRepository.createMany(seeds);

    return buildLockerPayload(locker, boxes);
  }

  async listLockers(query) {
    const listQuery = parseListQuery(query, {
      defaultSort: '-createdAt',
      allowedSortFields: [
        'createdAt',
        'updatedAt',
        'lockerName',
        'lockerId',
        'status',
        'totalBoxes',
        'terminalNumber',
      ],
      filterFields: {
        status: 'status',
        lockerId: 'lockerId',
        terminalNumber: 'terminalNumber',
      },
      searchFields: ['lockerName', 'lockerId', 'description'],
    });

    if (listQuery.filter.lockerId) {
      listQuery.filter.lockerId = String(listQuery.filter.lockerId).toUpperCase();
    }

    const origin = parseOrigin(query);
    const { items, total } = await lockerRepository.list(listQuery);

    const lockers = await Promise.all(
      items.map(async (locker) => {
        const boxes = await boxRepository.findByLocker(locker._id);
        const availableItems = await Stock.countDocuments({
          locker: locker._id,
          currentQuantity: { $gt: 0 },
          status: { $in: ['IN_STOCK', 'LOW_STOCK'] },
        });
        return buildLockerPayload(locker, boxes, origin, { availableItems });
      }),
    );

    if (query.sort === 'distance' && origin) {
      lockers.sort((a, b) => {
        const da = a.distanceInMeters == null ? Number.MAX_SAFE_INTEGER : a.distanceInMeters;
        const db = b.distanceInMeters == null ? Number.MAX_SAFE_INTEGER : b.distanceInMeters;
        return da - db;
      });
    }

    return {
      lockers,
      pagination: buildPagination({
        page: listQuery.page,
        limit: listQuery.limit,
        total,
      }),
    };
  }

  async getLockerById(id, query = {}) {
    const locker = await lockerRepository.findByIdOrLockerId(id);
    if (!locker) {
      throw new AppError('Locker not found', 404);
    }

    const boxes = await boxRepository.findByLocker(locker._id);
    const origin = parseOrigin(query);
    const availableItems = await Stock.countDocuments({
      locker: locker._id,
      currentQuantity: { $gt: 0 },
      status: { $in: ['IN_STOCK', 'LOW_STOCK'] },
    });
    return buildLockerPayload(locker, boxes, origin, { availableItems });
  }

  async updateLocker(id, payload) {
    const locker = await lockerRepository.findByIdOrLockerId(id);
    if (!locker) {
      throw new AppError('Locker not found', 404);
    }

    if (payload.lockerId) {
      const nextLockerId = String(payload.lockerId).trim().toUpperCase();
      if (
        nextLockerId !== locker.lockerId &&
        (await lockerRepository.existsByLockerId(nextLockerId, locker._id))
      ) {
        throw new AppError('Locker ID already exists', 409);
      }
      payload.lockerId = nextLockerId;
    }

    if (payload.terminalNumber !== undefined) {
      const terminalNumber = Number(payload.terminalNumber);
      if (
        !Number.isInteger(terminalNumber) ||
        terminalNumber < 1 ||
        terminalNumber > 255
      ) {
        throw new AppError(
          'terminalNumber must be an integer between 1 and 255',
          400,
        );
      }
      if (
        terminalNumber !== locker.terminalNumber &&
        (await lockerRepository.existsByTerminalNumber(terminalNumber, locker._id))
      ) {
        throw new AppError(
          'Terminal number already assigned to another locker',
          409,
        );
      }
      payload.terminalNumber = terminalNumber;
    }

    const previousTotal = locker.totalBoxes;
    const updated = await lockerRepository.updateById(locker._id, payload);
    if (!updated) {
      throw new AppError('Locker not found', 404);
    }

    if (payload.totalBoxes !== undefined && payload.totalBoxes !== previousTotal) {
      await this.syncBoxCount(updated, previousTotal, payload.totalBoxes);
    }

    const boxes = await boxRepository.findByLocker(updated._id);
    return buildLockerPayload(updated, boxes);
  }

  async syncBoxCount(locker, previousTotal, nextTotal) {
    if (nextTotal > previousTotal) {
      const seeds = [];
      for (let number = previousTotal + 1; number <= nextTotal; number += 1) {
        seeds.push(buildBoxSeed(locker, number));
      }
      await boxRepository.createMany(seeds);
      return;
    }

    if (nextTotal < previousTotal) {
      const trailing = await boxRepository.findTrailingBoxes(locker._id, nextTotal);
      const blocked = trailing.filter(
        (box) => box.status === 'RESERVED' || box.status === 'AVAILABLE' || !box.isEmpty,
      );

      if (blocked.length > 0) {
        throw new AppError(
          'Cannot reduce totalBoxes while non-empty or reserved boxes exist at the end',
          400,
        );
      }

      await boxRepository.deleteManyByIds(trailing.map((box) => box._id));
    }
  }

  async deleteLocker(id) {
    const locker = await lockerRepository.findByIdOrLockerId(id);
    if (!locker) {
      throw new AppError('Locker not found', 404);
    }

    await boxRepository.deleteByLocker(locker._id);
    await lockerRepository.deleteById(locker._id);

    return { id: locker._id, lockerId: locker.lockerId };
  }
}

module.exports = new LockerService();
module.exports.buildBoxPayload = buildBoxPayload;
module.exports.buildLockerPayload = buildLockerPayload;
