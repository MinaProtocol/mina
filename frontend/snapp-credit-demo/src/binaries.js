/* Modified from: https://stackoverflow.com/a/52991116/4160498 */

const path = require("path");
const { app } = require("electron");

const { isPackaged } = app;
const root = process.cwd();

const binariesPath = isPackaged
  ? path.join(path.dirname(app.getAppPath()), "../", "./Resources", "./bin")
  : path.join(root, "./resources", "./bin");

const execPath = path.resolve(
  path.join(binariesPath, "./credit_score_demo.exe")
);

exports.execPath = execPath;
