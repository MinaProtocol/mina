// test creating a recursive proof with pickles

import snarkyjs from "./snarkyjs.js";
await snarkyjs.snarky_ready;
let { Circuit, Field, Pickles } = snarkyjs;

export { picklesProof };

function main(root) {
  root.mul(root).assertEquals(new Field(4));
}

async function picklesProof() {
  let name = "pickles proof test";
  console.log(name);

  let witnesses = [new Field(2)];
  let witnessTypes = [FieldTyp];
  let rule = createDummyRule("dummy", main, witnessTypes);

  console.log("compile...");
  let start = Date.now();
  let compiled = compile([rule]);
  let { provers, verify } = compiled;
  let time = Date.now() - start;
  console.log(`compiled proof system in ${(time / 1000).toFixed(2)} sec`);

  console.log("prove...");
  start = Date.now();
  let { statement, proof } = await prove(provers[0], main, witnesses);
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
  let output = Pickles.compile(rules);
  mainContext = undefined;
  return output;
}

async function prove(prover, func, args) {
  // run rule to get the statement
  let statement = Circuit.runAndCheckSync(() => {
    mainContext = {};
    func(...args);
    mainContext = undefined;
    // TODO this is a dummy statement
    let statementVar = { transaction: Field.one, atParty: Field.one };
    return {
      transaction: statementVar.transaction.toConstant(),
      atParty: statementVar.atParty.toConstant(),
    };
  });
  // prove
  mainContext = {
    witnesses: args,
  };
  let proof = await prover(statement);
  mainContext = undefined;
  return { proof, statement };
}

function createDummyRule(name, func, witnessTypes) {
  function main(statement) {
    // get the private inputs from current context and call the function with them
    let { witnesses } = mainContext;
    witnesses = witnessTypes.map(
      witnesses
        ? (type, i) => Circuit.witness(type, () => witnesses[i])
        : emptyWitness
    );
    func(...witnesses);
    // dummy constraint
    let { transaction } = statement;
    transaction.assertEquals(transaction);
  }
  // return (name, main) in the format OCaml expects
  return [0, name, main];
}

function emptyWitness(typ) {
  // return typ.ofFields(Array(typ.sizeInFields()).fill(Field.zero));
  return Circuit.witness(typ, () =>
    typ.ofFields(Array(typ.sizeInFields()).fill(Field.zero))
  );
}

let FieldTyp = {
  sizeInFields: () => 1,
  toFields: (f) => [f],
  ofFields: ([f]) => f,
};
