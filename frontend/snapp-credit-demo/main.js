const { app, BrowserWindow, Menu, ipcMain } = require("electron");
const { scrape } = require("./src/puppeteer");
const { generateSnapp } = require("./src/snapp");
const { LOGIN, VALID_LOGIN, INVALID_LOGIN } = require("./constants");

process.env.NODE_ENV = "production";

const isDev = process.env.NODE_ENV !== "production" ? true : false;
const isMac = process.platform === "darwin" ? true : false;
let mainWindow;

const createMainWindow = async () => {
  mainWindow = new BrowserWindow({
    title: "SNAPP Credit Check",
    width: isDev ? 1200 : 600,
    height: 650,
    resizable: isDev ? true : false,
    backgroundColor: "white",
    webPreferences: {
      enableRemoteModule: true,
      nodeIntegration: true,
    },
  });

  if (isDev) {
    mainWindow.webContents.openDevTools();
  }
  mainWindow.loadFile("./app/index.html");
};

app.on("ready", async () => {
  createMainWindow();
  const mainMenu = Menu.buildFromTemplate(menu);
  Menu.setApplicationMenu(mainMenu);
  await mainWindow.webContents.executeJavaScript(
    'localStorage.setItem("loading", false);'
  );
  mainWindow.on("closed", () => (mainWindow = null));
});

const menu = [
  {
    role: "fileMenu",
  },
  ...(isMac
    ? [
        {
          label: "Edit",
          submenu: [
            { role: "undo" },
            { role: "redo" },
            { type: "separator" },
            { role: "cut" },
            { role: "copy" },
            { role: "paste" },
            { role: "pasteandmatchstyle" },
            { role: "delete" },
            { role: "selectall" },
          ],
        },
      ]
    : []),
  ...(isDev
    ? [
        {
          label: "Developer",
          submenu: [
            { role: "reload" },
            { role: "forcereload" },
            { type: "separator" },
            { role: "toggledevtools" },
          ],
        },
      ]
    : []),
];

app.on("activate", async () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createMainWindow();
  }
});

app.on("window-all-closed", () => {
  if (!isMac) {
    app.quit();
  }
});

ipcMain.on(LOGIN, (_, { ethAddress, email, password, domain }) => {
  scrape({ email, password, mainWindow, domain })
    .then((creditScore) => {
      mainWindow.webContents.send(VALID_LOGIN);
      generateSnapp(mainWindow, ethAddress, creditScore);
    })
    .catch((err) => {
      mainWindow.webContents.send(INVALID_LOGIN);
      console.error(err);
    });
});
