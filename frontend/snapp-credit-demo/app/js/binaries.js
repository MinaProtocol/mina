const path = require("path");
const { app } = require("electron");
const { rootPath } = require("electron-root-path");

const IS_PROD = process.env.NODE_ENV === "production";
const root = rootPath;
const { getAppPath } = app;
const isPackaged = process.mainModule.filename.indexOf("app.asar") !== -1;

const binariesPath =
  IS_PROD && isPackaged
    ? path.join(path.dirname(getAppPath()), "..", "./Resources", "./bin")
    : path.join(root, "./resources", "./bin");

const execPath = path.resolve(
  path.join(binariesPath, "./credit_score_demo.exe")
);

exports.execPath = execPath;
