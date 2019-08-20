function renderParticipant(participant, rank) {
  const row = document.createElement("div");
  row.className = "leaderboard-row";

  function appendColumn(value) {
    const cell = document.createElement("span");
    cell.textContent = value;
    row.appendChild(cell);
  }

  if (participant.length > 2) {
    appendColumn(rank); // rank
    appendColumn(participant[0]); // name
    appendColumn(participant[participant.length - 1]); // current week score
    appendColumn(participant[1]); // total score
  }
  return row;
}

function start() {
  gapi.client
    .init({
      apiKey: "AIzaSyDIFwMr7SPGCLl_o6e4UZKi1q9l8snkUZs"
    })
    .then(function() {
      return gapi.client.request({
        path:
          "https://sheets.googleapis.com/v4/spreadsheets/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/values/C3:N"
      });
    })
    .then(
      function(response) {
        const {
          result: {
            values,
          }
        } = response;
        // Update the current week header dynamically
        if (values.length) {
          const headers = values.shift();
          const currentWeekElem = document.getElementById("leaderboard-current-week");
          currentWeekElem.textContent = headers[values[0].length - 1];
        }
        // Add rows to leaderboard container
        const parentElem = document.getElementById("testnet-leaderboard");
        values.map((participant, index) => {
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
