importScripts('https://unpkg.com/promise-worker/dist/promise-worker.register.js');
// importScripts("/verifier.bc.js");

// msg: {
//  key : sexp str,
//  a, str,
//  b : str,
//  c : str,
//  delta_prime : str,
//  z : str,
//  stateHashField : str,
// }
registerPromiseWorker(function (msg) {
  // var key = snarkette.createVerificationKey(msg.key);
  // var proof = snarkette.constructProof(a, b, c, delta_prime, z);
  // return snarkette.verifyStateHashField(key, msg.stateHashField, proof)

  var before = new Date();
  while ((new Date() - before) < msg) { }
  var after = new Date();

  return {verified: true, time: after - before};
});
