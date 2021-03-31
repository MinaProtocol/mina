const { exec } = require("child_process");
const { execPath } = require("./binaries");
const fs = require("fs");

const {
  PROOF_SUCCESS,
  PROOF_FAIL,
  CREDIT_SCORE,
  CREDIT_FAIL,
} = require("../constants");

const execSnappCommand = (execPath, ethAddress, creditScore) => {
  const snappPublicKey =
    "B62qpeeaJV6jm3FZL9hvApQ7CjbwiLL8TXbZBWZwJwSm3rqM7yUmRLC";
  const receiverPublicKey =
    "B62qnW5wYBhf9zCKSpyp3Q9bhEBgx47aP3iLAVbWHi2diSHFNG6Nwtw";
  const fee = "10000000";
  const amount = "10000000";

  return `
    ${execPath} prove --score ${creditScore}\
    --eth-address ${ethAddress}\
    --snapp-public-key ${snappPublicKey}\
    --receiver-public-key ${receiverPublicKey}\
    --fee ${fee}\
    --amount ${amount}`;
};

const generateSnapp = async (mainWindow, ethAddress, creditScore) => {
  let outputPath = await mainWindow.webContents.executeJavaScript(
    'localStorage.getItem("output-path");',
    true
  );

  if (!outputPath || !creditScore) {
    mainWindow.webContents.send(PROOF_FAIL);
    return;
  }

  if (creditScore < CREDIT_SCORE) {
    mainWindow.webContents.send(CREDIT_FAIL);
    return;
  }

  exec(execSnappCommand(execPath, ethAddress, creditScore), (error, stdout) => {
    if (error) {
      mainWindow.webContents.send(PROOF_FAIL);
    } else {
      const output = stdout.substr(stdout.indexOf("mutation"));
      fs.writeFileSync(outputPath, output);
      mainWindow.webContents.send(PROOF_SUCCESS);
    }
  });
};

exports.generateSnapp = generateSnapp;
