const path = require("path");
const { ipcRenderer, remote } = require("electron");
const { dialog } = remote;

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
  if (localStorage.getItem("loading") === true) {
    return;
  }

  const ethAddress = document.getElementById("eth-address")?.value;
  const email = document.getElementById("email")?.value;
  const password = document.getElementById("password")?.value;
  const outputPath = document.getElementById("output-path-display")?.value;

  localStorage.setItem("loading", true);

  if (ethAddress && email && password && outputPath) {
    ipcRenderer.send("button:gen-snapp", {
      ethAddress,
      email,
      password,
    });
  } else {
    document.getElementById("progress-container").classList.remove("hide");
    document.getElementById("progress-status-text").innerText =
      "All fields are required, please fill them before continuing";
  }
});

const chooseFolder = () => {
  return new Promise(function (resolve) {
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
        console.log(err);
      });
  });
};

ipcRenderer.on("status:web-scrape", () => {
  let status = document.getElementById("progress-status-text");
  let progressSpinner = document.getElementById("progress-status-spinner");
  progressSpinner.classList.add("active");
  let progressLoader = document.getElementById("progress-container");
  progressLoader.classList.remove("hide");
  status.innerText =
    "Attempting to log in, please do not close the application...";
});

ipcRenderer.on("status:valid-login", () => {
  document.getElementById("progress-container").classList.remove("hide");
  document.getElementById("progress-status-spinner").classList.add("active");
  document.getElementById("progress-status-text").innerText =
    "Login successful. Generating SNAPP proof...";
});

ipcRenderer.on("status:invalid-login", () => {
  document.getElementById("progress-container").classList.remove("hide");
  document.getElementById("progress-status-spinner").classList.remove("active");
  document.getElementById("progress-status-text").innerText =
    "Login unsuccessful. Please check your credentials or restart the application and try again.";
  localStorage.setItem("loading", false);
});

ipcRenderer.on("status:proof-gen", () => {
  const outputPath = localStorage.getItem("output-path", true);
  document.getElementById(
    "progress-status-text"
  ).innerText = `SNAPP proof generated to: ${outputPath}`;

  document.getElementById("progress-status-spinner").classList.remove("active");
  localStorage.setItem("loading", false);
});

ipcRenderer.on("status:proof-fail", () => {
  const outputPath = localStorage.getItem("output-path", true);
  document.getElementById(
    "progress-status-text"
  ).innerText = `Failed to generate proof to: ${outputPath}`;

  document.getElementById("progress-status-spinner").classList.remove("active");
  localStorage.setItem("loading", false);
});
