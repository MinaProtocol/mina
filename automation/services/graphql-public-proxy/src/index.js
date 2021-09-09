const express = require('express');
const http = require('http');
const httpProxy = require('http-proxy');
const cors = require('cors');
const bodyParser = require('body-parser');
const { graphqlExpress, graphiqlExpress } = require('apollo-server-express');
const {
  makeRemoteExecutableSchema,
  introspectSchema,
  transformSchema,
  FilterRootFields } = require('graphql-tools');
const {HttpLink} = require('apollo-link-http');
const fetch = require('node-fetch');
const fs = require('fs');

const CODA_GRAPHQL_HOST = process.env["CODA_GRAPHQL_HOST"] || "localhost";
const CODA_GRAPHQL_PORT = process.env["CODA_GRAPHQL_PORT"] || 3085;
const CODA_GRAPHQL_PATH = process.env["CODA_GRAPHQL_PATH"] || "/graphql";
const EXTERNAL_PORT = process.env["EXTERNAL_PORT"] || 3000;

let graphqlUri = "http://" + CODA_GRAPHQL_HOST + ":" + CODA_GRAPHQL_PORT + CODA_GRAPHQL_PATH;

const hiddenFields = [
  "trackedAccounts",
  "currentSnarkWorker",
  "initialPeers",
  "wallet",
];

const transformers = [
  new FilterRootFields((operation, fieldName, field) => !field.isDeprecated),
  new FilterRootFields((operation, fieldName, field) => operation != 'Mutation'),
  new FilterRootFields((operation, fieldName, field) => hiddenFields.indexOf(fieldName) < 0),
];

const graphiqlString = fs.readFileSync("./index.html");

// Define apollo link
const link = new HttpLink({ uri: graphqlUri, fetch });

// Set up proxy server for websocket
let proxy = httpProxy.createProxyServer({ target: {host: CODA_GRAPHQL_HOST, port: CODA_GRAPHQL_PORT},  ws: true});
proxy.on('error', err => console.log('Error in proxy server:', err));
//proxy.listen(CODA_GRAPHQL_PORT);

introspectSchema(link)
.then(remoteSchema => {
  return makeRemoteExecutableSchema({
    schema: remoteSchema,
    link,
  });
}).then(schema => {
  let app = express();
  let server = http.createServer(app);

  app.use(cors());

  // The GraphQL endpoint
  app.use('/graphql',
    bodyParser.json(), 
    (req, res, next) => {
      if (req.headers["accept"] == "application/json" || req.headers["content-type"] == "application/json") {
        req.headers["accept"] == "application/json";
        req.headers["content-type"] == "application/json";
        graphqlExpress({ schema: transformSchema(schema, transformers) })(req, res, next)
      } else {
        res.setHeader('Content-Type', 'text/html');
        res.write(graphiqlString);
        res.end();
      }
    },
  );

  // Proxy websocket upgrades
  server.on('upgrade', (req, socket, head) => proxy.ws(req, socket, head));

  server.listen(EXTERNAL_PORT);

  console.log('Go to http://localhost:' + EXTERNAL_PORT + '/graphql to run queries!');
});
