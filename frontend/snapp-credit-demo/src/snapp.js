const { exec } = require("child_process");
const { execPath } = require("./binaries");
const fs = require("fs");

const {
  PROOF_SUCCESS,
  PROOF_FAIL,
  CREDIT_SCORE,
  CREDIT_FAIL,
} = require("../constants");

const isMac = process.platform === "darwin" ? true : false;

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

const writeOutputToFile = (output, outputPath) => {
  const proofOutput = output.substr(output.indexOf("mutation"));
  fs.writeFileSync(outputPath, proofOutput);
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
      /*
        Snapp executable returns an error code of 1 on Mac even if it's successful
        so we skip over that. Otherwise consider it an error.
      */
      if (isMac && error.code === 1) {
        writeOutputToFile(stdout, outputPath);
        mainWindow.webContents.send(PROOF_SUCCESS);
      } else {
        mainWindow.webContents.send(PROOF_FAIL);
      }
    } else {
      writeOutputToFile(stdout, outputPath);
      mainWindow.webContents.send(PROOF_SUCCESS);
    }
  });
};

exports.generateSnapp = generateSnapp;
