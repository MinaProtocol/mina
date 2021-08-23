const path = require('path');

const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const NodePolyfillPlugin = require('node-polyfill-webpack-plugin');

module.exports = {
  target: 'web',

  devtool: false,

  // bundling mode
  mode: 'none',

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
          },
        },
      },
    ],
  },
  plugins: [new CleanWebpackPlugin(), new NodePolyfillPlugin()],
  optimization: {
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
