// Tests for the !ci-docker-me parameters.
//
// Run with: node test/docker-filters.test.js
//
// BUILDKITE_PIPELINE_FILTER is put into a dhall expression as the name of a
// union alternative, so a name that TagFilter.dhall does not declare stops the
// build with a dhall type error that says nothing about the comment. The first
// test reads TagFilter.dhall, so the list in index.js cannot fall behind it.

const assert = require("assert");
const fs = require("fs");
const path = require("path");

const { buildEnvFromParams, DOCKER_BUILD_FILTERS } = require("../src/docker-filters.js");

const TAG_FILTER_DHALL = path.join(
  __dirname,
  "..",
  "..",
  "..",
  "buildkite",
  "src",
  "Pipeline",
  "TagFilter.dhall"
);

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

// ---------------------------------------------------------------------------

test("the list of filters is the same as in TagFilter.dhall", () => {
  const source = fs.readFileSync(TAG_FILTER_DHALL, "utf8");

  // Take the alternatives of the union only, which are between "= <" and ">".
  const union = source.slice(source.indexOf("= <"), source.indexOf("\n      >"));
  const declared = new Set(
    (union.match(/DockerBuild[A-Za-z0-9]*/g) || []).filter(
      (name) => name.length > 0
    )
  );

  const known = new Set(DOCKER_BUILD_FILTERS);

  const missing = [...declared].filter((name) => !known.has(name)).sort();
  const extra = [...known].filter((name) => !declared.has(name)).sort();

  assert.deepStrictEqual(
    { missing, extra },
    { missing: [], extra: [] },
    "docker-filters.js and TagFilter.dhall disagree.\n" +
      `  declared in dhall but not in docker-filters.js: ${missing.join(", ") || "-"}\n` +
      `  in docker-filters.js but not declared in dhall: ${extra.join(", ") || "-"}\n` +
      "Update DOCKER_BUILD_FILTERS in src/docker-filters.js."
  );
});

test("no parameter builds every docker image", () => {
  const result = buildEnvFromParams({});
  assert.deepStrictEqual(result.env, {
    BUILDKITE_PIPELINE_FILTER: "DockerBuild",
  });
});

test("a complete set of parameters gives the filter, the mode and Full", () => {
  const result = buildEnvFromParams({
    arch: "amd64",
    profile: "devnet",
    codename: "bookworm",
  });
  assert.deepStrictEqual(result.env, {
    BUILDKITE_PIPELINE_FILTER: "DockerBuildAmd64DevnetBookworm",
    BUILDKITE_PIPELINE_FILTER_MODE: "All",
    BUILDKITE_PIPELINE_JOB_SELECTION: "Full",
  });
});

// The change based triage must not remove what the author asked for by name.
test("a build that names what to build is not triaged", () => {
  const result = buildEnvFromParams({ arch: "amd64" });
  assert.strictEqual(result.env.BUILDKITE_PIPELINE_JOB_SELECTION, "Full");
});

test("the architecture alone is enough", () => {
  const result = buildEnvFromParams({ arch: "arm64" });
  assert.strictEqual(result.env.BUILDKITE_PIPELINE_FILTER, "DockerBuildArm64");
});

test("the architecture and the profile are enough", () => {
  const result = buildEnvFromParams({ arch: "amd64", profile: "lightnet" });
  assert.strictEqual(
    result.env.BUILDKITE_PIPELINE_FILTER,
    "DockerBuildAmd64Lightnet"
  );
});

// These are the ones that used to reach buildkite and die there.
test("a combination with no filter is refused, not started", () => {
  // TagFilter.dhall declares no name for a profile on its own.
  const profileOnly = buildEnvFromParams({ profile: "devnet" });
  assert.ok(profileOnly.error, "a profile on its own must be refused");
  assert.ok(
    profileOnly.error.includes("DockerBuildDevnet"),
    "the message must name the filter that was composed"
  );

  // The three values are all correct, but this combination is not declared.
  const gap = buildEnvFromParams({
    arch: "arm64",
    profile: "devnet",
    codename: "jammy",
  });
  assert.ok(gap.error, "arm64 + devnet + jammy has no filter and must be refused");
  assert.ok(
    !DOCKER_BUILD_FILTERS.includes("DockerBuildArm64DevnetJammy"),
    "if this filter is added, change this test"
  );
});

test("a value that is not known is refused and the choices are given", () => {
  const result = buildEnvFromParams({ arch: "x86", profile: "devnet" });
  assert.ok(result.error, "arch=x86 must be refused");
  assert.ok(result.error.includes("amd64"), "the message must give the choices");
  assert.strictEqual(result.env, undefined, "no build may start");
});

test("a codename on its own is refused", () => {
  const result = buildEnvFromParams({ codename: "bullseye" });
  assert.ok(result.error, "a codename on its own must be refused");
});

// ---------------------------------------------------------------------------

console.log("");
console.log(`${run} tests, ${run - failed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
