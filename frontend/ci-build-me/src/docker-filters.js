// The names that buildkite/src/Pipeline/Filter.dhall (TagFilter) actually
// declares. BUILDKITE_PIPELINE_FILTER is put straight into a dhall expression
// as the name of a union alternative:
//
//   tagFilter=(./buildkite/src/Pipeline/TagFilter.dhall).Type.${tagFilter}
//
// so a name that is not declared does not select nothing: it stops the build at
// the "Prepare monorepo triage" step with a dhall type error, which says
// nothing about the comment that caused it. The combinations are not complete
// (there is no DockerBuildArm64DevnetJammy, and no name for a profile alone),
// so the composed name must be checked before a build is started.
//
// test/docker-filters.test.js reads TagFilter.dhall and fails if this list and
// that file stop agreeing.
const DOCKER_BUILD_FILTERS = [
  "DockerBuild",
  "DockerBuildAmd64",
  "DockerBuildAmd64Devnet",
  "DockerBuildAmd64DevnetBookworm",
  "DockerBuildAmd64DevnetBullseye",
  "DockerBuildAmd64DevnetFocal",
  "DockerBuildAmd64DevnetJammy",
  "DockerBuildAmd64DevnetNoble",
  "DockerBuildAmd64Lightnet",
  "DockerBuildAmd64LightnetBookworm",
  "DockerBuildAmd64LightnetBullseye",
  "DockerBuildAmd64Mainnet",
  "DockerBuildAmd64MainnetBookworm",
  "DockerBuildAmd64MainnetBullseye",
  "DockerBuildAmd64MainnetFocal",
  "DockerBuildAmd64MainnetJammy",
  "DockerBuildAmd64MainnetNoble",
  "DockerBuildArm64",
  "DockerBuildArm64Devnet",
  "DockerBuildArm64DevnetBookworm",
  "DockerBuildArm64DevnetNoble",
  "DockerBuildArm64Lightnet",
  "DockerBuildArm64LightnetBookworm",
  "DockerBuildArm64Mainnet",
  "DockerBuildArm64MainnetBookworm",
  "DockerBuildArm64MainnetNoble",
];

const DOCKER_PROFILES = ["devnet", "lightnet", "mainnet"];
const DOCKER_ARCHES = ["amd64", "arm64"];
const DOCKER_CODENAMES = ["jammy", "noble", "bullseye", "focal", "bookworm"];

const capitalise = (value) => value.charAt(0).toUpperCase() + value.slice(1);

// Turn the key=value pairs of a !ci-docker-me comment into the environment of
// the build, or into the reason why no build can be started.
//
// Returns { env } when a build may start, or { error } with a text for the
// author of the comment.
const buildEnvFromParams = ({ arch, profile, codename }) => {
  // No key at all: build every docker image, as before.
  if (!arch && !profile && !codename) {
    return { env: { BUILDKITE_PIPELINE_FILTER: "DockerBuild" } };
  }

  const wrong = [];
  if (arch && !DOCKER_ARCHES.includes(arch)) {
    wrong.push(`arch=${arch} (use one of: ${DOCKER_ARCHES.join(", ")})`);
  }
  if (profile && !DOCKER_PROFILES.includes(profile)) {
    wrong.push(`profile=${profile} (use one of: ${DOCKER_PROFILES.join(", ")})`);
  }
  if (codename && !DOCKER_CODENAMES.includes(codename)) {
    wrong.push(`codename=${codename} (use one of: ${DOCKER_CODENAMES.join(", ")})`);
  }
  if (wrong.length > 0) {
    return { error: `!ci-docker-me: value not known: ${wrong.join("; ")}` };
  }

  // The name is composed in this order because that is the order the names in
  // TagFilter.dhall are written in.
  var filter = "DockerBuild";
  if (arch) filter += capitalise(arch);
  if (profile) filter += capitalise(profile);
  if (codename) filter += capitalise(codename);

  if (!DOCKER_BUILD_FILTERS.includes(filter)) {
    return {
      error:
        `!ci-docker-me: this combination has no filter (${filter}).\n` +
        `Give the architecture first, then the profile, then the codename, ` +
        `and use a combination that buildkite/src/Pipeline/TagFilter.dhall ` +
        `declares. These exist:\n` +
        DOCKER_BUILD_FILTERS.filter((f) => f !== "DockerBuild").join("\n"),
    };
  }

  return {
    env: {
      BUILDKITE_PIPELINE_FILTER: filter,
      BUILDKITE_PIPELINE_FILTER_MODE: "All",
      // The author named what to build, so the change based triage must not
      // take it away again. !ci-docker-base-me does the same.
      BUILDKITE_PIPELINE_JOB_SELECTION: "Full",
    },
  };
};

module.exports = {
  buildEnvFromParams,
  DOCKER_BUILD_FILTERS,
  DOCKER_ARCHES,
  DOCKER_PROFILES,
  DOCKER_CODENAMES,
};
