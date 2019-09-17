const { buildClientSchema, printSchema, introspectionQuery } = require("graphql");
const fs = require("fs");
const fetch = require('node-fetch')

if (process.argv.length < 3) {
  console.error("Invocation: node generate-schema.js <path|server>")
  process.exit(1)
}

function writeSchema(data) {
  const schema = buildClientSchema(data);
  console.log(printSchema(schema, {commentDescriptions: true}));
}

const endpoint = process.argv[2]
if (fs.existsSync(endpoint)) {
  let fileContents = fs.readFileSync(endpoint, {encoding: 'utf8'});
  let data = JSON.parse(fileContents)["data"];
  writeSchema(data);
} else {
  console.error("Fetching from server.");
  fetch(endpoint, {
    method: "POST",
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: introspectionQuery }),
  })
  .then(res => res.json())
  .then(json => {
    writeSchema(json.data)
  }).catch(e => {
    console.error("Error in query: " + e);
  })
}
