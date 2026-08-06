'use strict';

/**
 * Builds Mongo query options for list endpoints.
 * Supports pagination, filtering, sorting, and text search.
 */
function parseListQuery(query, options = {}) {
  const {
    defaultSort = '-createdAt',
    allowedSortFields = ['createdAt', 'updatedAt'],
    filterFields = {},
    searchFields = [],
  } = options;

  const page = Math.max(1, Number(query.page) || 1);
  const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
  const skip = (page - 1) * limit;

  const filter = {};

  Object.entries(filterFields).forEach(([queryKey, mongoField]) => {
    if (query[queryKey] !== undefined && query[queryKey] !== '') {
      filter[mongoField] = query[queryKey];
    }
  });

  if (query.search && searchFields.length > 0) {
    const term = String(query.search).trim();
    if (term) {
      filter.$or = searchFields.map((field) => ({
        [field]: { $regex: term, $options: 'i' },
      }));
    }
  }

  let sort = defaultSort;
  if (query.sort) {
    const requested = String(query.sort)
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean);

    const safe = requested.filter((part) => {
      const field = part.startsWith('-') ? part.slice(1) : part;
      return allowedSortFields.includes(field);
    });

    if (safe.length > 0) {
      sort = safe.join(' ');
    }
  }

  return {
    page,
    limit,
    skip,
    filter,
    sort,
  };
}

function buildPagination({ page, limit, total }) {
  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPrevPage: page > 1,
  };
}

module.exports = {
  parseListQuery,
  buildPagination,
};
