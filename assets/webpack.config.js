const path = require('path')

module.exports = (env, options) => {
  return {
    entry: './js/phoenix_live_view/index.js',
    output: {
      filename: 'phoenix_live_view.js',
      path: path.resolve(__dirname, '../priv/static'),
      library: {
        name: 'phoenix_live_view',
        type: 'umd'
      },
      globalObject: 'this'
    },
    devtool: 'source-map',
    module: {
      rules: [
        {
          test: require.resolve('phoenix_live_view'),
          loader: 'expose-loader',
          options: {
            exposes: ['Phoenix.LiveView']
          }
        }
      ]
    },
    plugins: []
  }
}
