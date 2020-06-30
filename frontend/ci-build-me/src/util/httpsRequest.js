const { promisify } = require("util");
const https = require("https");
const HTTPError = require("./httpError");

// Maintain persistent connections instead of creating a new connection on every function invocation
const agent = new https.Agent({ keepAlive: true });

https.request[promisify.custom] = (options, postData) =>
  new Promise((resolve, reject) => {
    if (!options.agent) {
      options.agent = agent; // eslint-disable-line no-param-reassign
    }
    const req = https.request(options, (response) => {
      if (
        (response.statusCode < 200 || response.statusCode >= 300) &&
        response.statusCode != 422
      ) {
        return reject(new HTTPError(response.statusCode));
      }

      let body = [];
      response
        .on("data", (chunk) => {
          body.push(chunk);
        })
        .on("end", () => {
          try {
            body = Buffer.concat(body);
            if (response.headers["content-type"].includes("application/json")) {
              body = JSON.parse(body);
            } else {
              body = body.toString();
            }
          } catch (e) {
            reject(e);
          }
          resolve(body);
        });
      return null;
    });

    req.on("error", (err) => {
      reject(err);
    });
    if (postData) {
      req.write(postData);
    }
    req.end();
  });

exports.httpsRequest = promisify(https.request);
