let snarkyjs = require("./snarkyjs");

async function main() {
  await snarkyjs.snarky_ready;

  snarkyjs.shutdown();
}

main();
