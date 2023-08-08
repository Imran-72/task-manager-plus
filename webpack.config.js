const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const webpack = require('webpack');

module.exports = {
  entry: './index.js',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
    clean: true,
  },
  plugins: [new HtmlWebpackPlugin({ template: './public/index.html' })],
  mode: 'development',
  devServer: {
    historyApiFallback: true,
    static: {
      directory: path.resolve(__dirname, 'dist'),
    },
    open: true,
    compress: true,
    hot: true,
    port: 8080,
  },
  module: {
    rules: [
      {
        test: /\.(js|jsx)$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-react'],
          },
        },
      },
    ],
  },
  resolve: {
    extensions: ['.js', '.jsx'],
  },
};
