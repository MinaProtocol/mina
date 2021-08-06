import typescript from '@rollup/plugin-typescript';
import babel from '@rollup/plugin-babel';
import commonjs from '@rollup/plugin-commonjs';
import json from '@rollup/plugin-json';

export default [
  {
    input: 'src/index.ts',
    output: {
      file: 'dist/snarkyjs.esm.js',
      format: 'es',
    },
    plugins: [
      json(),
      typescript(),
      commonjs(),
      babel({
        exclude: 'node_modules/**',
        sourceMaps: false,
      }),
    ],
  },
  {
    input: 'src/index.ts',
    output: {
      file: 'dist/snarkyjs.cjs.js',
      format: 'cjs',
    },
    plugins: [
      json(),
      typescript(),
      commonjs(),
      babel({
        exclude: 'node_modules/**',
        sourceMaps: false,
      }),
    ],
  },
  // Build Snarky.js individually
  // {
  //   input: 'src/bindings/snarky.js',
  //   output: {
  //     file: 'dist/snarkyjs-ocaml.esm.js',
  //     format: 'esm',
  //   },
  //   plugins: [
  //     json(),
  //     commonjs(),
  //     babel({
  //       exclude: 'node_modules/**',
  //       sourceMaps: false,
  //     }),
  //   ],
  // },
];
