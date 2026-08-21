// Tests for the check on values taken from a pull request comment.
//
// Run with: node test/safe-input.test.js
//
// These values are put into a dhall expression on the build agent, and dhall
// can read the environment, so a value that leaves its text literal can run
// code there. The tests below are written as attempts, not as tidy examples.

const assert = require("assert");
const { checkArgument, MAX_LENGTH } = require("../src/safe-input.js");

let run = 0;
let failed = 0;

const test = (name, fn) => {
  run += 1;
  try {
    fn();
    console.log(`ok    ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`FAIL  ${name}`);
    console.error(`      ${error.message.split("\n").join("\n      ")}`);
  }
};

const refused = (value) => {
  const result = checkArgument("test", value);
  assert.ok(result.error, `'${value}' must be refused`);
  assert.strictEqual(result.value, undefined, `'${value}' must give no value`);
  return result.error;
};

const allowed = (value) => {
  const result = checkArgument("test", value);
  assert.ok(!result.error, `'${value}' must be allowed, got: ${result.error}`);
  assert.strictEqual(result.value, value);
};

// ---------------------------------------------------------------------------

test("a job name is allowed", () => {
  allowed("HardForkTestMixed");
  allowed("TestnetIntegrationTestsLocalApps");
  allowed("MinaArtifactBookwormArm64");
});

test("a step pattern is allowed", () => {
  allowed("rosetta_config-devnet-docker-image");
  allowed("_MinaArtifactBullseye-archive-devnet-docker-image");
  allowed("daemon_*-devnet-docker-image");
  allowed("archive-devnet-docker-image, daemon_config-devnet-docker-image");
  allowed("buildkite/src/gen");
});

// The one that matters: leaving the dhall text literal.
test("a value that closes the dhall text is refused", () => {
  const error = refused('x" ++ env:BUILDKITE_AGENT_ACCESS_TOKEN ++ "');
  assert.ok(error.includes('"'), "the message must name the quotation mark");
  assert.ok(
    error.includes("dhall"),
    "the message must say why, so the reason is not guessed"
  );
});

test("the marks needed to leave a text or a shell are refused", () => {
  refused('name"');
  refused("name\\");
  refused("name$(id)");
  refused("name`id`");
  refused("name${X}");
  refused("name;id");
  refused("name|id");
  refused("name&id");
  refused("name>out");
  refused("name'x'");
  refused("name(x)");
  refused("name{x}");
  refused("env:SECRET");
});

test("a line end is refused", () => {
  refused("name\nsecond line");
  refused("name\r\nsecond line");
  refused("name\ttab");
});

test("nothing at all is refused", () => {
  refused("");
  refused(undefined);
  refused(null);
});

test("a value that is not text is refused", () => {
  refused(42);
  refused({});
  refused(["a"]);
});

test("a very long value is refused", () => {
  allowed("a".repeat(MAX_LENGTH));
  const error = refused("a".repeat(MAX_LENGTH + 1));
  assert.ok(error.includes(String(MAX_LENGTH)), "the message must give the limit");
});

test("the message names every character that is wrong, one time each", () => {
  const error = refused('a"b"c\\d');
  assert.ok(error.includes('"'), "must name the quotation mark");
  assert.ok(error.includes("\\"), "must name the backslash");
  // '"' appears twice in the value but must be reported once.
  assert.strictEqual(
    (error.match(/"/g) || []).length,
    1,
    "each character is named one time"
  );
});

test("the name of the command is in the message", () => {
  const result = checkArgument("!ci-single-me", 'bad"value');
  assert.ok(result.error.startsWith("!ci-single-me:"));
});

// ---------------------------------------------------------------------------

console.log("");
console.log(`${run} tests, ${run - failed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
