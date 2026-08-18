const github = require("./util/github");
const HTTPError = require("./util/httpError");

const { httpsRequest } = require("./util/httpsRequest");
const axios = require("axios");
const { checkArgument } = require("./safe-input.js");
const { parseArtifactsCommand } = require("./artifacts.js");

const apiKey = process.env.BUILDKITE_API_ACCESS_TOKEN;

const runBuild = async (github, pipeline_name, env) => {
  const postData = JSON.stringify({
    commit: github.pull_request.head.sha,
    branch: github.pull_request.head.ref,
    ignore_pipeline_branch_filters: true,
    author: {
      name: github.sender.login,
    },
    pull_request_base_branch: github.pull_request.base.ref,
    pull_request_id: github.pull_request.number,
    pull_request_repository: github.pull_request.head.repo.clone_url,
    env: env,
  });

  const options = {
    hostname: "api.buildkite.com",
    port: 443,
    path: `/v2/organizations/o-1-labs-2/pipelines/${pipeline_name}/builds`,
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(postData),
    },
  };
  const request = await httpsRequest(options, postData);
  return request;
};

const hasExistingBuilds = async (github) => {
  const options = {
    hostname: "api.buildkite.com",
    port: 443,
    path: `/v2/organizations/o-1-labs-2/pipelines/mina/builds?branch=${encodeURIComponent(
      github.pull_request.head.ref
    )}&commit=${encodeURIComponent(
      github.pull_request.head.sha
    )}&state=running&state=finished`,
    method: "GET",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
  };
  const request = await httpsRequest(options);
  return request.length > 0;
};

const getRequest = async (url) => {
  const request = await axios.get(url);
  if (request.status < 200 || request.status >= 300) {
    throw new HTTPError(request.status);
  }
  return request;
};

const parseParams = (comment) => {
  // comment looks like: "!ci-docker-me arch=amd64 profile=devnet"
  const parts = comment.split(/\s+/).slice(1); // drop the "!ci-docker-me"
  const params = {};
  for (const part of parts) {
    const [key, value] = part.split("=");
    if (key && value) {
      params[key.trim()] = value.trim();
    }
  }
  return params;
};

const buildEnvFromParams = ({ arch, profile, codename }) => {
  var filter = "DockerBuild";

  // Only fall back to the unfiltered DockerBuild when the caller gave nothing.
  // A caller that gives some of the keys keeps them: "arch=amd64" alone builds
  // the filter DockerBuildAmd64, which is a real filter.
  if (!arch && !profile && !codename) {
    return { BUILDKITE_PIPELINE_FILTER: filter };
  }

  const profiles = ["devnet", "lightnet", "mainnet"];
  const arches = ["amd64", "arm64"];
  const codenames = ["jammy", "noble", "bullseye", "focal", "bookworm"];


  if (arches.includes(arch)) {
    filter += arch.charAt(0).toUpperCase() + arch.slice(1); // Amd64 / Arm64
  }

  if (profiles.includes(profile)) {
    filter += profile.charAt(0).toUpperCase() + profile.slice(1); // Devnet / Lightnet / Mainnet
  }

  if (codenames.includes(codename)) {
    filter += codename.charAt(0).toUpperCase() + codename.slice(1); // Jammy / Noble / Bullseye / Focal / Bookworm
  }

    return { BUILDKITE_PIPELINE_FILTER: filter, BUILDKITE_PIPELINE_FILTER_MODE: "All" };
};
// -------------------

const handler = async (event, req) => {
  const buildkiteTrigger = {};
  // PR Gating Lifting section
  if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!approved-for-mainnet"
  ) {
     // TODO: Actually look at @MinaProtocol/stakeholder-reviewers team instead of hardcoding the users here
    if (
      req.body.sender.login == "amc-ie" ||
      req.body.sender.login == "deepthiskumar" ||
      req.body.sender.login == "georgeee" ||
      req.body.sender.login == "dannywillems"
    ) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-pr-gating",
        { PR_GATE: "lifted" }
      );
      return buildkite;
    } else {
      return [
        "comment author is not authorized to approve for mainnet",
        "comment author is not authorized to approve for mainnet",
      ];
    }
  }

  // Mina CI Build section (nix-based)
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!ci-nix-me"
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-nix-experimental",
        {}
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina CI Build section
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!ci-build-me"
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (
      orgData.data.filter((org) => org.login == "MinaProtocol").length > 0 ||
      req.body.sender.login == "ylecornec" ||
      req.body.sender.login == "balsoft" ||
      req.body.sender.login == "bryanhonof"
    ) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-o-1-labs",
        {}
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina CI Nightly Build section
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!ci-nightly-me"
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-end-to-end-nightlies",
        {}
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina CI Single Test Build section
  //
  // Runs one generated buildkite job and the jobs it depends on. The job name
  // is the last word of the comment, and it must be the exact name of a job in
  // buildkite/src/gen (the match is on the whole name, not a part of it).
  //
  //   !ci-single-me HardForkTestMixed
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body.startsWith("!ci-single-me")
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);

      const jobName = req.body.comment.body.trim().split(/\s+/).pop(); // get JobName from "!ci-single-me JobName"

      // The name is put into a dhall expression on the agent, so it is checked
      // before it goes anywhere. See src/safe-input.js.
      const checked = checkArgument("!ci-single-me", jobName);
      if (checked.error) {
        return [checked.error, checked.error];
      }

      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-single-job",
        { JOB_NAME: checked.value }
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina CI Debian Build section
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!ci-debian-me"
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-build-debian",
        {}
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina Artifact Build section
  //
  // Builds artifacts: docker images, debian packages, or the app binaries they
  // are made from. What to build is named in the comment, and nothing is
  // triaged.
  //
  //   !ci-artifacts-me docker set=automode profile=devnet codename=bullseye
  //   !ci-artifacts-me debian set=prefork codename=bullseye
  //   !ci-artifacts-me apps codename=bullseye instrumented=true
  //
  // This is a NEW command with a pipeline of its own, and !ci-docker-me and
  // !ci-debian-me below are deliberately left alone. This function serves every
  // branch, and a buildkite pipeline runs one command for every branch alike,
  // while the entrypoint this pipeline uploads
  // (buildkite/src/Entrypoints/RunSelection.dhall) is on develop and on nothing
  // else. Changing the old commands would break every pull request on
  // compatible, on master and on the release branches. See src/artifacts.js.
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body.startsWith("!ci-artifacts-me")
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);

      const parsed = parseArtifactsCommand(req.body.comment.body);
      if (parsed.error) {
        return [parsed.error, parsed.error];
      }

      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-artifacts",
        parsed.env
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina Base Docker Build section
  //
  // Rebuilds ONLY the shared mina-base images (the common base-deps layer that
  // the daemon/archive/hardfork images are built FROM), across every codename.
  //
  // Has its own pipeline (mina-docker-base-build) and its own tag: the base jobs
  // are tagged Base, not Toolchain. The base image is debian-slim + shared apt
  // deps + the gcloud SDK, which has nothing in common with the opam toolchain,
  // so neither should be rebuilt because the other changed. !ci-toolchain-me
  // therefore does NOT rebuild the base images, and this does not rebuild the
  // toolchains.
  //
  // BaseDockersOnly selects the Base tag (see buildkite/src/Pipeline/TagFilter.dhall),
  // and Full skips dirty-when triage so the rebuild happens even when the PR did
  // not touch dockerfiles/stages/1-base-deps -- which is the whole point of an
  // on-demand rebuild command.
  //
  // Kept ABOVE the !ci-docker-me branch on purpose: that one matches on a
  // prefix, so anything sharing its prefix must be handled before it.
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!ci-docker-base-me"
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-docker-base-build",
        {
          BUILDKITE_PIPELINE_FILTER: "BaseDockersOnly",
          BUILDKITE_PIPELINE_JOB_SELECTION: "Full",
        }
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body.startsWith("!ci-docker-me")
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);

      const params = parseParams(req.body.comment.body);
      const env = buildEnvFromParams(params);

      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-build-docker",
        env
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  // Mina Toolchain Build section
  else if (
    req.body.action == "created" &&
    req.body.issue.pull_request &&
    req.body.issue.pull_request.url &&
    req.body.comment.body == "!ci-toolchain-me"
  ) {
    const orgData = await getRequest(req.body.sender.organizations_url);
    if (orgData.data.filter((org) => org.login == "MinaProtocol").length > 0) {
      const prData = await getRequest(req.body.issue.pull_request.url);
      const buildkite = await runBuild(
        {
          sender: req.body.sender,
          pull_request: prData.data,
        },
        "mina-toolchains-build",
        {}
      );
      return [buildkite];
    } else {
      return [
        "comment author is not (publically) a member of the core team",
        "comment author is not (publically) a member of the core team",
      ];
    }
  }

  return null;
};

/**
 * HTTP Cloud Function for GitHub Webhook events.
 *
 * @param {object} req Cloud Function request context.
 * @param {object} res Cloud Function response context.
 */
exports.githubWebhookHandler = async (req, res) => {
  try {
    if (!req || !res || !req.method) {
      throw new HTTPError(400);
    }

    if (req.method !== "POST") {
      console.info(
        `Rejected ${req.method} request from ${req.ip} (${req.headers["user-agent"]})`
      );
      throw new HTTPError(405, "Only POST requests are accepted");
    }
    console.info(
      `Received request from ${req.ip} (${req.headers["user-agent"]})`
    );

    // Verify that this request came from GitHub
    github.validateWebhook(req);

    const githubEvent = req.headers["x-github-event"];
    const buildkite = await handler(githubEvent, req);
    if (buildkite && buildkite.web_url) {
      console.info(`Triggered buildkite build at ${buildkite.web_url}`);
    } else {
      console.error(`Failed to trigger buildkite build for some reason:`);
      console.error(buildkite);
    }
    res.status(200);
    console.info(`HTTP 200: ${githubEvent} event`);
    res.send({ buildkite } || {});
  } catch (e) {
    if (e instanceof HTTPError) {
      res.status(e.statusCode).send(e.message);
      console.info(`HTTP ${e.statusCode}: ${e.message}`, e);
    } else {
      res.status(500).send(e.message);
      console.error(`HTTP 500: ${e.message}`);
    }
  }
};
