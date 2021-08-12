const path = require('path');

let SnarkyNodeConfig = {
  target: 'node',

  devtool: false,

  // bundling mode
  mode: 'production',

  // entry files
  entry: './src/index.ts',

  // output bundles (location)
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'snarkyjs_node.js',
  },

  //file resolutions
  resolve: {
    extensions: ['.ts', '.js'],
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
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env'],
            sourceMaps: false,
          },
        },
      },
    ],
  },
};

module.exports = [SnarkyNodeConfig];
