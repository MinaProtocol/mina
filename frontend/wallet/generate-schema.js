const { buildClientSchema, printSchema, introspectionQuery } = require("graphql");
const fs = require("fs");
const fetch = require('node-fetch')

if (process.argv.length < 3) {
  console.error("Invocation: node generate-schema.js <server>")
  process.exit(1)
}

const endpoint = process.argv[2]

fetch(endpoint, {
  method: "POST",
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: introspectionQuery }),
})
.then(res => res.json())
.then(json => {
  const schema = buildClientSchema(json.data);
  console.log(printSchema(schema, {commentDescriptions: true}));
}).catch(e => {
  console.error("Error in query: " + e);
})


