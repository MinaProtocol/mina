let coda = require("../../../../_build/default/src/app/client_sdk/client_sdk.bc.js").codaSDK;

let keypair = { 
  privateKey: 
    "6BnSDyt3FKhJSt5oDk1HHeM5J8uKSnp7eaSYndj53y7g7oYzUEhHFrkpk6po4XfNFyjtoJK4ovVHvmCgdUqXVEfTXoAC1CNpaGLAKtu7ah9i4dTi3FtcoKpZhtiTGrRQkEN6Q95cb39Kp",
  publicKey: 
    "4vsRCVnc5xmYJhaVbUgkg6po6nR3Mu7KEFunP3uQL67qZmPNnJKev57TRvMfuJ15XDP8MjaLSh7THG7CpTiTkfgRcQAKGmFo1XGMStCucmWAxBUiXjycDbx7hbVCqkDYiezM8Lvr1NMdTEGU",
};

let receiver =
  "4vsRCVHzeYYbneMkHR3u445f8zYwo6nhx3UHKZQH7B2txTV5Shz66Ds9PdxoRKCiALWtuwPQDwpm2Kj22QPcZpKCLr6rnHmUMztKpWxL9meCPQcTkKhmK5HyM4Y9dMnTKrEjD1MX71kLTUaP";

let newDelegate =
  "4vsRCVQNkGihARy4Jg9FsJ6NFtnwDsRnTqi2gQnPAoCNUoyLveY6FEnicGMmwEumPx3GjLxAb5fAivVSLnYRPPMfb5HdkhLdjHunjgqp6g7gYi8cWy4avdmHMRomaKkWyWeWn91w7baaFnUk";

let payments = [ 
    { 
      paymentPayload: {receiver, amount: "42"},
      common: {fee: "3", nonce: "200", validUntil:"10000", memo: "this is a memo"},
    },
    { 
      paymentPayload: {receiver, amount: "2048"},
      common: {fee: "15", nonce: "212", validUntil:"305", memo: "this is not a pipe"},
    },
    { 
      paymentPayload: {receiver, amount: "109"},
      common: {fee: "2001", nonce: "3050", validUntil:"9000", memo: "blessed be the geek"},
    },
  ];

let delegations = [ 
    { 
      newDelegate,
      common: {fee: "3", nonce: "10", validUntil:"4000", memo: "more delegates, more fun"},
    },
    { 
      newDelegate,
      common: {fee: "10", nonce: "1000", validUntil:"8192", memo: "enough stake to kill a vampire"},
    },
    { 
      newDelegate,
      common: {fee: "8", nonce: "1010", validUntil:"100000", memo: "another memo"},
    },
  ];

let printSignature = s => console.log(`  { field: '${s.field}'\n  , scalar: '${s.scalar}'\n  },`);

console.log("[");
payments.forEach(t => printSignature(coda.signPayment(keypair.privateKey, t).signature));
delegations.forEach(t => printSignature(coda.signStakeDelegation(keypair.privateKey, t).signature));
console.log("]");
