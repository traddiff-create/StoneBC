const catalog = require('./routes-catalog.json');

module.exports = async function (data) {
  const community = data.communityRoutes || [];
  return [...catalog, ...community];
};
