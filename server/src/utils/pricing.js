'use strict';

/**
 * Pricing helpers for cart and order totals.
 */
function roundMoney(value) {
  return Number((Number(value) || 0).toFixed(2));
}

function lineSubtotal(quantity, priceAtPurchase) {
  return roundMoney(Number(quantity) * Number(priceAtPurchase));
}

function lineTax(subtotal, gstPercentage) {
  return roundMoney(subtotal * ((Number(gstPercentage) || 0) / 100));
}

function summarizeLines(lines, discount = 0) {
  let subtotal = 0;
  let tax = 0;

  const normalized = lines.map((line) => {
    const sub = lineSubtotal(line.quantity, line.priceAtPurchase);
    const gst = lineTax(sub, line.gstPercentage);
    subtotal += sub;
    tax += gst;
    return {
      ...line,
      subtotal: sub,
    };
  });

  const safeDiscount = roundMoney(Math.max(0, discount));
  const grandTotal = roundMoney(Math.max(0, subtotal + tax - safeDiscount));

  return {
    items: normalized,
    subtotal: roundMoney(subtotal),
    tax: roundMoney(tax),
    discount: safeDiscount,
    grandTotal,
  };
}

function generateOrderNumber() {
  const now = new Date();
  const stamp = [
    now.getUTCFullYear(),
    String(now.getUTCMonth() + 1).padStart(2, '0'),
    String(now.getUTCDate()).padStart(2, '0'),
    String(now.getUTCHours()).padStart(2, '0'),
    String(now.getUTCMinutes()).padStart(2, '0'),
    String(now.getUTCSeconds()).padStart(2, '0'),
  ].join('');
  const rand = Math.floor(Math.random() * 9000 + 1000);
  return `ORD-${stamp}-${rand}`;
}

function generateCartId(userId) {
  return `CART-${String(userId).slice(-6).toUpperCase()}-${Date.now().toString(36).toUpperCase()}`;
}

module.exports = {
  roundMoney,
  lineSubtotal,
  lineTax,
  summarizeLines,
  generateOrderNumber,
  generateCartId,
};
