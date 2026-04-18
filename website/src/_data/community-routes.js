const { getStore } = require('@netlify/blobs');

module.exports = async function () {
  try {
    const store = getStore('approved-routes');
    const { blobs } = await store.list();
    const routes = await Promise.all(blobs.map(b => store.getJSON(b.key)));
    return routes.filter(Boolean);
  } catch {
    return [];
  }
};
