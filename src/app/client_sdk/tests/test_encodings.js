// test_encodings.js -- print Rosetta encodings of a couple of public keys

var coda = require("../../../../_build/default/src/app/client_sdk/client_sdk.bc.js").codaSDK;

var pk1 = "B62qkef7po74VEvJYcLYsdZ83FuKidgNZ8Xiaitzo8gKJXaxLwxgG7T";
var pk2 = "B62qnekV6LVbEttV7j3cxJmjSbxDWuXa5h3KeVEXHPGKTzthQaBufrY";

var enc1 = coda.rawPublicKeyOfPublicKey(pk1)
var enc2 = coda.rawPublicKeyOfPublicKey(pk2)

console.log(enc1)
console.log(enc2)
