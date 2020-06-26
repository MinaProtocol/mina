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

function renderChallenge(challenge) {
  const challengeItem = document.createElement("div");
  challengeItem.className = "challenge-item";

  const challengeName = document.createElement("h4");
  challengeName.className = "challenge-name";
  challengeName.textContent = challenge.name;

  const challengeDescription = document.createElement("p");
  challengeDescription.className = "challenge-description";
  challengeDescription.innerHTML = marked(challenge.description);

  challengeItem.appendChild(challengeName);
  challengeItem.appendChild(challengeDescription);
  return challengeItem;
}

function startLeaderboard() {
  return gapi.client.request({
    path:
      "https://sheets.googleapis.com/v4/spreadsheets/1Nq_Y76ALzSVJRhSFZZm4pfuGbPkZs2vTtCnVQ1ehujE/values/C3:N"
  }).then(
    function (response) {
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
      // Sort values by latest week
      values.sort((a, b) => {
        const size = a.length;
        return b[size - 1] - a[size - 1];
      });
      // Add rows to leaderboard container
      const parentElem = document.getElementById("testnet-leaderboard");
      values.map((participant, index) => {
        parentElem.appendChild(renderParticipant(participant, index + 1));
      });
      // Hide the loader
      document.getElementById("leaderboard-loading").style.display = "none";
    },
    function (reason) {
      console.log("Error: " + reason.result.error.message);
    }
  );
}

function startChallenges() {
  return gapi.client.request({
    path:
      "https://sheets.googleapis.com/v4/spreadsheets/1Nq_Y76ALzSVJRhSFZZm4pfuGbPkZs2vTtCnVQ1ehujE/values/Challenges!A:AZ"
  }).then(
    function (response) {
      const {
        result: {
          values,
        }
      } = response;
      const latestChallenges = values[values.length - 1];
      // Set name of challenges header
      const currentWeekChallenge = document.getElementById("challenges-current-week");
      currentWeekChallenge.textContent = latestChallenges.shift();
      // Pop extra challenge name if description is missing
      if (latestChallenges.length % 2 !== 0) {
        latestChallenges.pop();
      }
      const parentElem = document.getElementById("challenges-list");
      for (let i = 0; i < latestChallenges.length; i += 2) {
        const challenge = {
          name: latestChallenges[i],
          description: latestChallenges[i + 1]
        }
        parentElem.appendChild(renderChallenge(challenge));
      }
    },
    function (reason) {
      console.log("Error: " + reason.result.error.message);
    }
  );
}

function start() {
  gapi.client
    .init({
      apiKey: "AIzaSyDIFwMr7SPGCLl_o6e4UZKi1q9l8snkUZs"

    })
    .then(function () {
      startChallenges();
      startLeaderboard();
    })
}
// 1. Load the JavaScript client library.
gapi.load("client", start);