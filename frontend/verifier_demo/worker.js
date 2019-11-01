importScripts('https://unpkg.com/promise-worker/dist/promise-worker.register.js');
importScripts("/verifier.bc.js");
// while ((new Date() - before) < msg) { }

// msg: {
//  key : sexp str,
//  a, str,
//  b : str,
//  c : str,
//  delta_prime : str,
//  z : str,
//  stateHashField : str,
// }
//

registerPromiseWorker(function (msg) {
  var before = new Date();
  var key = snarkette.createVerificationKey(msg.key);
  var proof = snarkette.constructProof(msg.a, msg.b, msg.c, msg.delta_prime, msg.z);
  var verified = snarkette.verifyStateHash(key, msg.stateHashField, proof)
  var after = new Date();

  return {verified: verified, time: after - before};
});
