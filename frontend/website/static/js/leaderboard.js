function renderParticipant(participant, rank) {
  const row = document.createElement("div");
  row.className = "leaderboard-row";
  if (participant.length == 2) {
    const rankCell = document.createElement("span");
    rankCell.textContent = rank;
    row.appendChild(rankCell);

    const nameCell = document.createElement("span");
    nameCell.textContent = participant[0];
    row.appendChild(nameCell);

    const scoreCell = document.createElement("span");
    scoreCell.textContent = participant[1];
    row.appendChild(scoreCell);
  }
  return row;
}

function start() {
  gapi.client
    .init({
      // apiKey: "AIzaSyDIFwMr7SPGCLl_o6e4UZKi1q9l8snkUZs"
      apiKey: "AIzaSyB_AJlZmkWNwDHaznJStaHINij7pu0nNA8"
    })
    .then(function() {
      return gapi.client.request({
        path:
          "https://sheets.googleapis.com/v4/spreadsheets/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/values/C4:D"
      });
    })
    .then(
      function(response) {
        const parentElem = document.getElementById("testnet-leaderboard");
        response.result.values.map((participant, index) => {
          parentElem.appendChild(renderParticipant(participant, index + 1));
        });
        // Hide the loader
        document.getElementById("leaderboard-loading").style.display = "none";
      },
      function(reason) {
        console.log("Error: " + reason.result.error.message);
      }
    );
}

// 1. Load the JavaScript client library.
gapi.load("client", start);
