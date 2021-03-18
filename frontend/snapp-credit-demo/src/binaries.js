/* Modified from: https://stackoverflow.com/a/52991116/4160498 */

const path = require("path");
const { app } = require("electron");

const { isPackaged } = app;
const root = process.cwd();

const isMac = process.platform === "darwin" ? true : false;
const linuxPath = path.join(
  path.dirname(app.getAppPath()),
  "../",
  "./resources",
  "./Resources",
  "./bin"
);
const macPath = path.join(
  path.dirname(app.getAppPath()),
  "../",
  "../",
  "./Contents",
  "./Resources",
  "./Resources",
  "./bin"
);

let binariesPath;
if (isPackaged) {
  binariesPath = isMac ? macPath : linuxPath;
} else {
  binariesPath = path.join(root, "./resources", "./bin");
}

const execPath = path.resolve(
  path.join(binariesPath, "./credit_score_demo.exe")
);

exports.execPath = execPath;
