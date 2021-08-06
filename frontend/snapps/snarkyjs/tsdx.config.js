// see https://tsdx.io/customization#rollup to better understand tsdx.config.js
const babel = require('@rollup/plugin-babel');
const commonjs = require('@rollup/plugin-commonjs');

module.exports = {
  rollup(config, options) {
    config.plugins.push(commonjs());
    config.plugins.push(babel.babel());
    return config;
  },
};
