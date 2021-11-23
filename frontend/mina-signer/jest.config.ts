import type { Config } from "@jest/types";
// Sync object
const config: Config.InitialOptions = {
  verbose: true,
  preset: "ts-jest",
  globals: {
    "ts-jest": {
      useESM: true,
      transform: {
        "^.+\\.ts?$": "ts-jest",
      },
      babelConfig: {
        presets: [
          ["@babel/preset-env", { targets: { node: "current" } }],
          "@babel/preset-typescript",
        ],
      },
    },
  },
};
export default config;
