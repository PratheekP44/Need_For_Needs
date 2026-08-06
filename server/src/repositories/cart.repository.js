'use strict';

const Cart = require('../models/Cart');

class CartRepository {
  async create(data) {
    return Cart.create(data);
  }

  async findById(id) {
    return Cart.findById(id)
      .populate('items.item')
      .populate('items.stock')
      .populate('items.locker', 'lockerId lockerName status')
      .populate('items.box', 'boxId boxNumber status isEmpty')
      .exec();
  }

  async findActiveByUser(userId) {
    return Cart.findOne({ user: userId, status: 'ACTIVE' })
      .populate('items.item')
      .populate('items.stock')
      .populate('items.locker', 'lockerId lockerName status')
      .populate('items.box', 'boxId boxNumber status isEmpty')
      .exec();
  }

  async save(cart) {
    return cart.save();
  }

  async updateById(id, data) {
    return Cart.findByIdAndUpdate(id, data, {
      new: true,
      runValidators: true,
    })
      .populate('items.item')
      .populate('items.stock')
      .populate('items.locker', 'lockerId lockerName status')
      .populate('items.box', 'boxId boxNumber status isEmpty')
      .exec();
  }
}

module.exports = new CartRepository();
