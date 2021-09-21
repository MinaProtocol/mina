const path = require('path');

const NodePolyfillPlugin = require('node-polyfill-webpack-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');

module.exports = {
  target: 'web',

  devtool: false,

  mode: 'none',

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

  resolve: {
    extensions: ['.ts', '.js'],
    fallback: {
      child_process: false,
      fs: false,
    },
  },

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

  plugins: [
    new CleanWebpackPlugin(),
    new NodePolyfillPlugin(),
    new CopyPlugin({
      patterns: [
        {
          from: './src/chrome_bindings/index.html',
          to: '',
        },
        {
          from: './src/chrome_bindings/server.py',
          to: '',
        },
        {
          from: './src/chrome_bindings/plonk_init.js',
          to: '',
        },
        {
          from: './src/chrome_bindings/plonk_wasm.js',
          to: '',
        },
        {
          from: './src/chrome_bindings/plonk_wasm_bg.wasm',
          to: '',
        },
        {
          from: 'src/chrome_bindings/snippets',
          to: 'snippets',
        },
      ],
    }),
  ],
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
