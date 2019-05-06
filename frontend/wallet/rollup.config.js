import resolve from 'rollup-plugin-node-resolve';
import commonjs from 'rollup-plugin-commonjs';

export default {
  input: './lib/js/src/main/app.js',
  output: {
    file: './app.js',
    format: 'cjs'
  },
  external: ["electron"],
  plugins: [
    resolve(),
    commonjs()
  ]
};
