import type { Config } from "@jest/types";
const config: Config.InitialOptions = {
  verbose: true,
  preset: "ts-jest",
  modulePathIgnorePatterns: ["<rootDir>/dist/"],
  globals: {
    "ts-jest": {
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
