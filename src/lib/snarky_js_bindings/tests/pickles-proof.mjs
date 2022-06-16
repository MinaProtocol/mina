// test creating a recursive proof with pickles

import snarkyjs from "./snarkyjs.js";
await snarkyjs.snarky_ready;
let { Circuit, Field, Pickles, Poseidon } = snarkyjs;

export { picklesProof };

const trueFactors = [Field.random(), Field.random()];
const trueProduct = trueFactors[0].mul(trueFactors[1]);
const truePrehash = Field.random();
const trueHash = Poseidon.hash([truePrehash]);

function factors(x, y) {
  x.mul(y).assertEquals(trueProduct);
}

function hash(x) {
  Poseidon.hash([x]).assertEquals(trueHash);
}

async function picklesProof() {
  let name = "pickles proof test";
  console.log(name);

  let factorsRule = createDummyRule("factors", factors, [FieldTyp, FieldTyp]);
  let hashRule = createDummyRule("hash", hash, [FieldTyp]);
  let rules = [factorsRule, hashRule];
  let witnesses = [trueFactors, [truePrehash]];

  console.log("compile (proof system with two branches)...");
  let start = Date.now();
  let { provers, verify } = compile(rules);
  let time = Date.now() - start;
  console.log(`compiled proof system in ${(time / 1000).toFixed(2)} sec`);

  console.log("prove (first rule)...");
  start = Date.now();
  let { statement, proof } = await prove(provers[0], witnesses[0]);
  time = Date.now() - start;
  console.log(`created recursive proof in ${(time / 1000).toFixed(2)} sec`);

  console.log("verify...");
  let ok = await verify(statement, proof);

  console.log("ok?", ok === 1);
  if (!ok) throw Error(`${name} failed`);
}

let mainContext = undefined;

function compile(rules) {
  mainContext = {};
  let output = Pickles.compile(rules, 1);
  mainContext = undefined;
  return output;
}

async function prove(prover, args) {
  // prove
  mainContext = {
    witnesses: args,
  };
  let statement = [Field.one];
  let proof = await prover(statement, []);
  mainContext = undefined;
  return { proof, statement };
}

function createDummyRule(name, func, witnessTypes) {
  function main([statement]) {
    // get the private inputs from current context and call the function with them
    let { witnesses } = mainContext;
    witnesses = witnessTypes.map(
      witnesses
        ? (type, i) => Circuit.witness(type, () => witnesses[i])
        : emptyWitness
    );
    func(...witnesses);
    statement.assertEquals(1);
    return [];
  }
  return { identifier: name, main, proofsToVerify: [] };
}

function emptyWitness(typ) {
  return Circuit.witness(typ, () =>
    typ.ofFields(Array(typ.sizeInFields()).fill(Field.zero))
  );
}

let FieldTyp = {
  sizeInFields: () => 1,
  toFields: (f) => [f],
  ofFields: ([f]) => f,
  check: () => {},
};
