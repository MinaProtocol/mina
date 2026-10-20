// Tests for reading a !ci-artifacts-me comment.
//
// Run with: node test/artifacts.test.js
//
// The point of this command is that it is NEW. This function serves every
// branch, and a buildkite pipeline runs one command whatever the branch, while
// the entrypoint the artifact pipeline uploads lives on develop and nowhere
// else. So the old commands have to keep meaning exactly what they meant, and
// the last test here reads index.js to say so.

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { parseArtifactsCommand } = require("../src/artifacts.js");

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

const envOf = (comment) => {
  const parsed = parseArtifactsCommand(comment);
  assert.ok(!parsed.error, `unexpected error: ${parsed.error}`);
  return parsed.env;
};

const errorOf = (comment) => {
  const parsed = parseArtifactsCommand(comment);
  assert.ok(parsed.error, "expected this to be refused");
  return parsed.error;
};

// ---------------------------------------------------------------------------
// What a comment becomes
// ---------------------------------------------------------------------------

test("a docker build names the layer and the artifact", () => {
  assert.deepStrictEqual(
    envOf("!ci-artifacts-me docker set=automode profile=devnet codename=bullseye"),
    {
      BUILDKITE_PIPELINE_SELECTION: "automode",
      BUILDKITE_PIPELINE_PROFILE: "devnet",
      BUILDKITE_PIPELINE_CODENAME: "bullseye",
      BUILDKITE_PIPELINE_LAYER: "docker",
    }
  );
});

test("the same set in the debian layer only changes the layer", () => {
  const docker = envOf("!ci-artifacts-me docker set=automode");
  const debian = envOf("!ci-artifacts-me debian set=automode");
  assert.strictEqual(docker.BUILDKITE_PIPELINE_SELECTION, "automode");
  assert.strictEqual(debian.BUILDKITE_PIPELINE_SELECTION, "automode");
  assert.strictEqual(docker.BUILDKITE_PIPELINE_LAYER, "docker");
  assert.strictEqual(debian.BUILDKITE_PIPELINE_LAYER, "debian");
});

test("an app build asks for one step and carries no layer", () => {
  assert.deepStrictEqual(
    envOf("!ci-artifacts-me apps codename=bullseye instrumented=true"),
    {
      BUILDKITE_PIPELINE_CODENAME: "bullseye",
      BUILDKITE_PIPELINE_INSTRUMENTED: "true",
      BUILDKITE_PIPELINE_SELECTION: "build-apps",
    }
  );
});

test("naming no set is allowed, and means the whole layer", () => {
  assert.deepStrictEqual(envOf("!ci-artifacts-me docker"), {
    BUILDKITE_PIPELINE_LAYER: "docker",
  });
});

test("every axis reaches its own variable", () => {
  const env = envOf(
    "!ci-artifacts-me debian set=archive packages=archive_generic " +
      "codename=bullseye,jammy arch=arm64 network=devnet profile=lightnet " +
      "instrumented=both from=01234-abcd"
  );
  assert.deepStrictEqual(env, {
    BUILDKITE_PIPELINE_SELECTION: "archive",
    BUILDKITE_PIPELINE_DEB_SELECTION: "archive_generic",
    BUILDKITE_PIPELINE_CODENAME: "bullseye,jammy",
    BUILDKITE_PIPELINE_ARCH: "arm64",
    BUILDKITE_PIPELINE_NETWORK: "devnet",
    BUILDKITE_PIPELINE_PROFILE: "lightnet",
    BUILDKITE_PIPELINE_INSTRUMENTED: "both",
    BUILDKITE_PIPELINE_FROM_BUILD: "01234-abcd",
    BUILDKITE_PIPELINE_LAYER: "debian",
  });
});

// ---------------------------------------------------------------------------
// What is refused
// ---------------------------------------------------------------------------

test("a missing layer is refused, and the answer says the choices", () => {
  const error = errorOf("!ci-artifacts-me set=daemon");
  assert.ok(error.includes("docker, debian, apps"));
});

test("a layer that does not exist is refused", () => {
  errorOf("!ci-artifacts-me rosetta set=daemon");
});

// A key that is nearly right must not be ignored: silently building every
// codename is a much bigger build than the one that was asked for.
test("a misspelt key is refused, not ignored", () => {
  const error = errorOf("!ci-artifacts-me docker codenam=bullseye");
  assert.ok(error.includes("codename"), "the answer should list the real keys");
});

test("a word that is not key=value is refused", () => {
  errorOf("!ci-artifacts-me docker bullseye");
});

test("a value outside a closed list is refused by name", () => {
  const error = errorOf("!ci-artifacts-me docker arch=x86");
  assert.ok(error.includes("amd64"));
  errorOf("!ci-artifacts-me docker instrumented=maybe");
});

test("an app build takes no set", () => {
  errorOf("!ci-artifacts-me apps set=daemon");
  errorOf("!ci-artifacts-me apps packages=logproc");
});

// The values no longer reach a dhall expression, but the check stays: it costs
// nothing and it fails closed.
test("a value that tries to leave its quotes is refused", () => {
  errorOf("!ci-artifacts-me docker set=x\"+env:BUILDKITE_AGENT_ACCESS_TOKEN");
  errorOf("!ci-artifacts-me docker set=$(whoami)");
  errorOf("!ci-artifacts-me docker set=a`id`");
});

// ---------------------------------------------------------------------------
// Backward compatibility
// ---------------------------------------------------------------------------

// This function answers comments on every branch, and the artifact entrypoint
// is on develop only. If the old commands changed, or pointed at a pipeline
// whose command changed, every pull request on compatible and on master would
// break. So they must still trigger the pipelines they always triggered.
test("the old commands are untouched", () => {
  const index = fs.readFileSync(
    path.join(__dirname, "..", "src", "index.js"),
    "utf8"
  );

  assert.ok(
    /req\.body\.comment\.body == "!ci-debian-me"/.test(index),
    "!ci-debian-me must still match on the whole comment"
  );
  assert.ok(
    index.includes('"mina-build-debian"'),
    "!ci-debian-me must still start mina-build-debian"
  );
  assert.ok(
    index.includes('"mina-build-docker"'),
    "!ci-docker-me must still start mina-build-docker"
  );
  assert.ok(
    index.includes('"mina-single-job"'),
    "!ci-single-me must still start mina-single-job"
  );

  // The new command has a pipeline of its own, so nothing it does can reach a
  // branch that has no entrypoint for it.
  assert.ok(
    index.includes('"mina-artifacts"'),
    "!ci-artifacts-me must start a pipeline of its own"
  );
});

console.log("");
console.log(`${run} tests, ${run - failed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
