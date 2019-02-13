const path = require('path')

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
  plugins: []
}
