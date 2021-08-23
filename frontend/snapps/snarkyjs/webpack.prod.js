const path = require('path');

const TerserPlugin = require('terser-webpack-plugin');
const NodePolyfillPlugin = require('node-polyfill-webpack-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');

module.exports = {
  target: 'web',

  devtool: false,

  // bundling mode
  mode: 'production',

  // entry files
  entry: {
    snarkyjs_chrome: {
      import: path.resolve(__dirname, 'src/index.ts'),
      library: {
        name: 'snarky',
        type: 'umd',
        umdNamedDefine: true,
      },
    },
    plonk_init: {
      import: path.resolve(__dirname, 'chrome_test/plonk_init.js'),
      library: {
        name: 'plonk_init',
        type: 'umd',
        umdNamedDefine: true,
      },
    },
  },

  // output bundles (location)
  output: {
    path: path.resolve(__dirname, 'dist'),
    publicPath: '',
    filename: '[name].js',
    library: 'snarky',
    libraryTarget: 'umd',
    libraryExport: 'default',
    umdNamedDefine: true,
    clean: true,
  },

  //file resolutions
  resolve: {
    extensions: ['.ts', '.js'],
    fallback: {
      child_process: false,
      fs: false,
    },
  },

  // loaders
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: [
          {
            loader: 'ts-loader',
            options: {
              configFile: 'tsconfig.json',
            },
          },
        ],
        exclude: /node_modules/,
      },
      {
        test: /\.m?js$/,
        exclude: /(node_modules|snarky_js_chrome.bc.js)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env'],
            plugins: ['@babel/plugin-transform-runtime'],
            sourceMaps: false,
          },
        },
      },
      {
        test: /\.wasm$/,
        type: 'asset/resource',
        generator: {
          filename: 'plonk_wasm_bg.wasm',
        },
      },
    ],
  },
  plugins: [new CleanWebpackPlugin(), new NodePolyfillPlugin()],
  optimization: {
    minimize: true,
    minimizer: [new TerserPlugin()],
    splitChunks: {
      cacheGroups: {
        commons: {
          test: /\.bc.js$/,
          name: 'snarkyjs_chrome_bindings',
          chunks: 'all',
        },
      },
    },
  },
};
