const { app, BrowserWindow, Menu, ipcMain } = require("electron");
const { exec } = require("child_process");
const puppeteer = require("./app/js/puppeteer");
const { execPath } = require("./app/js/binaries");

process.env.NODE_ENV = "production";

const isDev = process.env.NODE_ENV !== "production" ? true : false;
let mainWindow;

const createMainWindow = async () => {
  mainWindow = new BrowserWindow({
    title: "SNAPP Credit Check",
    width: isDev ? 1200 : 600,
    height: 600,
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

let generateSnapp = async (ethAddress, creditScore) => {
  await mainWindow.webContents.executeJavaScript(
    'localStorage.setItem("loading", false);'
  );

  let outputPath = await mainWindow.webContents.executeJavaScript(
    'localStorage.getItem("output-path");',
    true
  );

  if (!outputPath || !creditScore) {
    mainWindow.webContents.send("status:proof-fail");
    return;
  }

  exec(
    `${execPath} -version | sed 's/$/ ${creditScore}/' > ${outputPath}`,
    (error) => {
      if (error) {
        mainWindow.webContents.send("status:proof-fail");
      } else {
        mainWindow.webContents.send("status:proof-gen");
      }
    }
  );
};

ipcMain.on("button:gen-snapp", (_, { ethAddress, email, password }) => {
  mainWindow.webContents.send("status:web-scrape");
  puppeteer
    .scrape(email, password)
    .then((creditScore) => {
      mainWindow.webContents.send("status:valid-login");
      generateSnapp(ethAddress, creditScore);
    })
    .catch((err) => {
      mainWindow.webContents.send("status:invalid-login");
      console.error(err);
    });
});
