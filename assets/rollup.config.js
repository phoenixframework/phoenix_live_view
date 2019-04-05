const path = require('path')
import resolve from 'rollup-plugin-node-resolve';
import commonjs from 'rollup-plugin-commonjs';
import babel from 'rollup-plugin-babel';
import { terser } from "rollup-plugin-terser";
import { sizeSnapshot } from "rollup-plugin-size-snapshot";


export default {
  external: ['phoenix'],
  input: './js/phoenix_live_view.js',
  output: {
    file: path.resolve(__dirname, '../priv/static/phoenix_live_view.js'),
    format: 'es',
    sourcemap: true
  },
  plugins: [
    resolve(),

    commonjs({
      namedExports: {
        '../deps/phoenix/priv/static/phoenix.js': ['Socket']
      }
    }),

    babel({
      exclude: ['node_modules/**','../deps/**'],
    }),

    (process.env.BUILD === 'production' && terser()),

    sizeSnapshot()
  ]
};

