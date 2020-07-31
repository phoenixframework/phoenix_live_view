const path = require('path')
const webpack = require('webpack')
const package = require("./package.json")

module.exports = {
  entry: './js/phoenix_live_view.js',
  output: {
    filename: 'phoenix_live_view.js',
    path: path.resolve(__dirname, '../priv/static'),
    library: 'phoenix_live_view',
    libraryTarget: 'umd',
    globalObject: 'this'
  },
  module: {
    rules: [
      {
        test: path.resolve(__dirname, './js/phoenix_live_view.js'),
        use: [{
          loader: 'expose-loader',
          options: 'Phoenix.LiveView'
        }]
      },
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      }
    ]
  },
  plugins: [
    new webpack.DefinePlugin({
      __PACKAGE_VERSION__: JSON.stringify(package.version)
    })
  ]
}
