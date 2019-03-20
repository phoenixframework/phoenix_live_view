// babel.config.js
module.exports = {
  presets: ["@babel/preset-env"],
  env: {
    test: {
      presets: [
        [
          "@babel/preset-env",
          {
            targets: {
              node: "10"
            }
          }
        ]
      ]
    }
  }
};
