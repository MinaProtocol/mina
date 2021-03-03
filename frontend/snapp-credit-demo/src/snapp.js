const { exec } = require("child_process");
const { execPath } = require("./binaries");
const { PROOF_SUCCESS, PROOF_FAIL } = require("../constants");

const execSnappCommand = (execPath, outputPath, creditScore) => {
  // This is just for demo purposes. These values should change on launch.
  const snappPublicKey =
    "B62qiyajxvnfKKx3KfQQTLV8xcb7LEgLmmqrdTgWoo7F5dVNMP2YXto";
  const receiverPublicKey =
    "B62qqYSLkTCoMVaPj5kfct9CxJcbDjVqb3LcstQShDtg2vck8mt5MRF";
  const fee = "10000000";
  const amount = "10000000";

  return `
    ${execPath} prove --score ${creditScore}\
    --snapp-public-key ${snappPublicKey}\
    --receiver-public-key ${receiverPublicKey}\
    --fee ${fee}\
    --amount ${amount}\
    > ${outputPath}`;
};

const generateSnapp = async (mainWindow, ethAddress, creditScore) => {
  let outputPath = await mainWindow.webContents.executeJavaScript(
    'localStorage.getItem("output-path");',
    true
  );

  mainWindow.webContents.send("debug", { execPath });
  if (!outputPath || !creditScore) {
    mainWindow.webContents.send(PROOF_FAIL);
    return;
  }

  exec(execSnappCommand(execPath, outputPath, creditScore), (error) => {
    if (error) {
      mainWindow.webContents.send(PROOF_FAIL);
    } else {
      mainWindow.webContents.send(PROOF_SUCCESS);
    }
  });
};

exports.generateSnapp = generateSnapp;
