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
//
function sexp_g1(arr) {
  return "(" + arr.join(" ") + ")"
}

function sexp_g2(arr) {
   return "(" + sexp_g1(arr[0]) + " " + sexp_g1(arr[1]) + ")"
}

registerPromiseWorker(function (msg) {
  var before = new Date();
  var key = snarkette.createVerificationKey(msg.key);
  var proof = snarkette.constructProof(
    sexp_g1(msg.a),
    sexp_g2(msg.b),
    sexp_g1(msg.c),
    sexp_g2(msg.delta_prime),
    sexp_g1(msg.z)
  );
  var o = {
    a: sexp_g1(msg.a),
    b: sexp_g2(msg.b),
    c: sexp_g1(msg.c),
    delta_prime: sexp_g2(msg.delta_prime),
    z: sexp_g1(msg.z)
  };
  var verified = snarkette.verifyStateHash(key, msg.stateHashField, proof)
  var after = new Date();

  return {verified: verified, time: after - before, obj: o};
});
