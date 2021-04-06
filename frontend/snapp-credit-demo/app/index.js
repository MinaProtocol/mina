const path = require("path");
const { ipcRenderer, remote } = require("electron");
const { dialog } = remote;
const {
  LOGIN,
  LOGIN_COM,
  LOGIN_CA,
  VALID_LOGIN,
  INVALID_LOGIN,
  PROOF_SUCCESS,
  PROOF_FAIL,
  CREDIT_FAIL,
  COM_DOMAIN,
  CA_DOMAIN,
} = require("../constants");

const hideProgressSpinner = () => {
  document.getElementById("progress-status-spinner").classList.remove("active");
};

const showProgressSpinner = () => {
  document.getElementById("progress-status-spinner").classList.add("active");
};

const setProgressStatusText = (status) => {
  document.getElementById("progress-status-text").innerText = status;
};

const chooseFolder = () => {
  return new Promise((resolve) => {
    dialog
      .showOpenDialog(remote.getCurrentWindow(), {
        properties: ["openDirectory"],
      })
      .then((result) => {
        if (result.canceled === false) {
          resolve(result.filePaths[0]);
        }
      })
      .catch((err) => {
        console.error(err);
      });
  });
};

const outputPathInput = document.getElementById("output-path-input");
outputPathInput.addEventListener("click", async (e) => {
  e.preventDefault();
  const folderLocation = await chooseFolder();
  const outputFilePath = path.join(folderLocation, "snapp-credit-score");

  document.getElementById("output-path-display").value = outputFilePath;
  localStorage.setItem("output-path", outputFilePath);
});

const form = document.getElementById("snapp-form");
form.addEventListener("submit", (e) => {
  e.preventDefault();
  if (localStorage.getItem("loading") === "true") {
    return;
  }

  const ethAddress = document.getElementById("eth-address")?.value;
  const email = document.getElementById("email")?.value;
  const password = document.getElementById("password")?.value;

  const outputPath = document.getElementById("output-path-display")?.value;
  const usaRadioBtn = document.getElementById("radio-usa")?.checked;
  const domain = usaRadioBtn ? COM_DOMAIN : CA_DOMAIN;
  localStorage.setItem("loading", true);

  if (ethAddress && email && password && outputPath) {
    ipcRenderer.send(LOGIN, {
      ethAddress,
      email,
      password,
      domain,
    });
  } else {
    setProgressStatusText(
      "All fields are required, please fill them before continuing"
    );
    localStorage.setItem("loading", false);
  }
});

ipcRenderer.on(VALID_LOGIN, () => {
  showProgressSpinner();
  setProgressStatusText(
    "Login successful. Attempting to generate SNAPP proof, this can take up to a few minutes. Please be patient..."
  );
});

ipcRenderer.on(INVALID_LOGIN, () => {
  hideProgressSpinner();
  setProgressStatusText(
    "Login unsuccessful. Please check your credentials or restart the application and try again."
  );
  localStorage.setItem("loading", false);
});

ipcRenderer.on(LOGIN_COM, () => {
  showProgressSpinner();
  setProgressStatusText(
    `Attempting to log into creditkarma.com, please do not close the application...`
  );
});

ipcRenderer.on(LOGIN_CA, () => {
  showProgressSpinner();
  setProgressStatusText(
    `Attempting to log into creditkarma.ca, please do not close the application...`
  );
});

ipcRenderer.on(PROOF_SUCCESS, () => {
  const outputPath = localStorage.getItem("output-path");
  setProgressStatusText(
    `Credit score is above 700, SNAPP proof succesfully saved to: ${outputPath}`
  );
  hideProgressSpinner();
  localStorage.setItem("loading", false);
});

ipcRenderer.on(PROOF_FAIL, () => {
  const outputPath = localStorage.getItem("output-path");
  setProgressStatusText(`Failed to generate proof to: ${outputPath}`);
  hideProgressSpinner();
  localStorage.setItem("loading", false);
});

ipcRenderer.on(CREDIT_FAIL, () => {
  const outputPath = localStorage.getItem("output-path");
  setProgressStatusText(
    `Credit score is less than 700, cannot produce SNAPP proof to: ${outputPath}`
  );
  hideProgressSpinner();
  localStorage.setItem("loading", false);
});
