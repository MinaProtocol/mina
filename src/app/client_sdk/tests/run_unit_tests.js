var mina = require("./client_sdk.js").minaSDK;

console.log("Running client SDK unit tests");
mina.runUnitTests()();
console.log("Done.");

mina.shutdown();
