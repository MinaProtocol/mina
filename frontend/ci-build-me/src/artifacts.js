// Read a !ci-artifacts-me comment and turn it into the environment of a build.
//
// Why this is a command of its own
// --------------------------------
// This function serves EVERY branch: it starts a build of the pull request's
// own branch, so a comment on a compatible or a master pull request runs that
// branch's buildkite tree. The artifact entrypoint
// (buildkite/src/Entrypoints/RunSelection.dhall) is on develop and on nothing
// else, and a buildkite pipeline runs one command for every branch alike.
//
// So !ci-docker-me and !ci-debian-me are left exactly as they are, pointing at
// the pipelines they always pointed at. This is a new command with a pipeline
// of its own, and it works on a branch that has the entrypoint. Once every
// branch has it, the old names can be pointed here and this note deleted.
//
// The shape
// ---------
//   !ci-artifacts-me <layer> [key=value ...]
//
//   layer          docker, debian or apps. The command carries the layer, so a
//                  set names only an artifact of the product.
//   set=           daemon, archive, rosetta, automode, prefork, all ... or a
//                  pattern for step keys. Naming nothing builds the whole layer.
//   packages=      narrows the debian packages further, inside what set= chose.
//   codename=      bullseye, focal, jammy, noble, bookworm
//   arch=          amd64, arm64
//   network=       devnet, mainnet
//   profile=       devnet, mainnet, lightnet
//   instrumented=  true, false (the default), both
//   from=          take the binaries and the packages from that earlier build
//
// A list is separated by commas: codename=bullseye,jammy.
//
// Everything travels in the ENVIRONMENT. No value reaches a dhall expression,
// which is what makes these harmless to begin with; they are checked all the
// same, because a check that costs nothing is worth having.

const { checkArgument } = require("./safe-input.js");

const LAYERS = ["docker", "debian", "apps"];

// key in the comment -> environment variable that run-selection.sh reads
const KEYS = {
  set: "BUILDKITE_PIPELINE_SELECTION",
  packages: "BUILDKITE_PIPELINE_DEB_SELECTION",
  codename: "BUILDKITE_PIPELINE_CODENAME",
  arch: "BUILDKITE_PIPELINE_ARCH",
  network: "BUILDKITE_PIPELINE_NETWORK",
  profile: "BUILDKITE_PIPELINE_PROFILE",
  instrumented: "BUILDKITE_PIPELINE_INSTRUMENTED",
  from: "BUILDKITE_PIPELINE_FROM_BUILD",
};

// Values that are a closed list. Checking them here names the word that is
// wrong, instead of starting a build that then matches nothing.
const ENUMS = {
  arch: ["amd64", "arm64"],
  instrumented: ["true", "false", "both"],
};

const listIsIn = (value, allowed) =>
  value.split(",").every((item) => allowed.includes(item.trim()));

// Returns { env } to start a build with, or { error } to answer the comment.
const parseArtifactsCommand = (comment) => {
  const words = comment.trim().split(/\s+/).slice(1); // drop "!ci-artifacts-me"
  const layer = words.shift();

  if (!layer || !LAYERS.includes(layer)) {
    return {
      error:
        `!ci-artifacts-me: say which layer to build first: ${LAYERS.join(", ")}.\n` +
        "  !ci-artifacts-me docker set=daemon codename=bullseye\n" +
        "  !ci-artifacts-me debian set=prefork\n" +
        "  !ci-artifacts-me apps codename=bullseye",
    };
  }

  const env = {};

  for (const word of words) {
    const at = word.indexOf("=");
    if (at < 1) {
      return {
        error:
          `!ci-artifacts-me: '${word}' is not a key=value. ` +
          `Known keys: ${Object.keys(KEYS).join(", ")}.`,
      };
    }

    const key = word.slice(0, at).trim();
    const value = word.slice(at + 1).trim();

    // An unknown key is refused rather than ignored: a comment that says
    // codenam=bullseye must not quietly build every codename.
    if (!Object.prototype.hasOwnProperty.call(KEYS, key)) {
      return {
        error:
          `!ci-artifacts-me: '${key}' is not a key. ` +
          `Known keys: ${Object.keys(KEYS).join(", ")}.`,
      };
    }

    const checked = checkArgument(`!ci-artifacts-me ${key}`, value);
    if (checked.error) {
      return { error: checked.error };
    }

    if (ENUMS[key] && !listIsIn(checked.value, ENUMS[key])) {
      return {
        error: `!ci-artifacts-me: ${key}=${checked.value} is not one of ${ENUMS[key].join(", ")}.`,
      };
    }

    env[KEYS[key]] = checked.value;
  }

  if (layer === "apps") {
    // An app build carries no artifact, no network and no profile: it compiles
    // everything there is. So it takes no set, and it needs no layer either --
    // it asks for one step by name.
    if (env.BUILDKITE_PIPELINE_SELECTION || env.BUILDKITE_PIPELINE_DEB_SELECTION) {
      return {
        error:
          "!ci-artifacts-me apps: an app build takes no set= and no packages=. " +
          "It compiles everything; what gets packaged out of it is the business " +
          "of the other layers.",
      };
    }
    env.BUILDKITE_PIPELINE_SELECTION = "build-apps";
  } else {
    env.BUILDKITE_PIPELINE_LAYER = layer;
  }

  return { env };
};

module.exports = { parseArtifactsCommand, LAYERS, KEYS };
