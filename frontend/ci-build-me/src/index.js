const github = require("./util/github");
const HTTPError = require("./util/httpError");

const { httpsRequest } = require("./util/httpsRequest");
const axios = require("axios");

const apiKey = process.env.BUILDKITE_API_ACCESS_TOKEN;
const circleApiKey = process.env.CIRCLECI_API_ACCESS_TOKEN;

const runCircleBuild = async (github) => {
  const postData = JSON.stringify({
    branch: `pull/${github.pull_request.number}/head`,
    parameters: {
      "run-ci": true,
    },
  });

  const options = {
    hostname: "circleci.com",
    port: 443,
    path: `/api/v2/project/github/MinaProtocol/mina/pipeline`,
    method: "POST",
    headers: {
      "Circle-token": circleApiKey,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
  };
  const request = await httpsRequest(options, postData);
  return request;
};

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

const handler = async (event, req) => {
  const buildkiteTrigger = {};
  if (event == "pull_request") {
    if (
      // if PR has ci-build-me label
      req.body.pull_request.labels.filter(
        (label) => label.name == "ci-build-me"
      ).length > 0 &&
      // and we are pushing new commits or actively adding this label
      (req.body.action == "synchronize" || req.body.action == "labeled") &&
      // and this is PR _not_ from a fork
      req.body.pull_request.head.user.login ==
        req.body.pull_request.base.user.login
    ) {
      let buildAlreadyExists;
      try {
        const res = await hasExistingBuilds(req.body);
        buildAlreadyExists = res;
      } catch (e) {
        // if this fails for some reason, assume we don't have an existing build
        console.error(`Failed to find existing builds:`);
        console.error(e);
        buildAlreadyExists = false;
      }

      if (!buildAlreadyExists) {
        const buildkite = await runBuild(req.body, "mina", {});
        const circle = await runCircleBuild(req.body);
        return [buildkite, circle];
      } else {
        console.info("Build for this commit on this branch was already found");
        return [
          "build already found for this commit",
          "build already found for this commit",
        ];
      }
    }
  } else if (event == "issue_comment") {
    // PR Gating Lifting section
    if (
      // we are creating the comment
      req.body.action == "created" &&
      // and this is actually a pull request
      req.body.issue.pull_request &&
      req.body.issue.pull_request.url &&
      // and the comment contents is exactly the slug we are looking for
      req.body.comment.body == "!approved-for-mainnet"
    ) {
      // TODO #7711: Actually look at @MinaProtocol/stakeholder-reviewers team instead of hardcoding the users here
      if (
        req.body.sender.login == "es92" ||
        req.body.sender.login == "aneesharaines" ||
        req.body.sender.login == "bkase" ||
        req.body.sender.login == "imeckler"
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
        return [buildkite, null];
      } else {
        return [
          "comment author is not (publically) a member of the core team",
          "comment author is not (publically) a member of the core team",
        ];
      }
    }

    // Mina CI Build section
    else if (
      // we are creating the comment
      req.body.action == "created" &&
      // and this is actually a pull request
      req.body.issue.pull_request &&
      req.body.issue.pull_request.url &&
      // and the comment contents is exactly the slug we are looking for
      req.body.comment.body == "!ci-build-me"
    ) {
      const orgData = await getRequest(req.body.sender.organizations_url);
      // and the comment author is part of the core team
      if (
        orgData.data.filter((org) => org.login == "MinaProtocol").length > 0
      ) {
        const prData = await getRequest(req.body.issue.pull_request.url);
        const buildkite = await runBuild(
          {
            sender: req.body.sender,
            pull_request: prData.data,
          },
          "mina",
          {}
        );
        const circle = await runCircleBuild({
          pull_request: prData.data,
        });
        return [buildkite, circle];
      } else {
        // NB: Users that are 'privately' a member of the org will not be able to trigger CI jobs
        return [
          "comment author is not (publically) a member of the core team",
          "comment author is not (publically) a member of the core team",
        ];
      }
    }
  }
  return [null, null];
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
    const [buildkite, circle] = await handler(githubEvent, req);
    if (buildkite && buildkite.web_url) {
      console.info(`Triggered buildkite build at ${buildkite.web_url}`);
    } else {
      console.error(`Failed to trigger buildkite build for some reason:`);
      console.error(buildkite);
    }

    if (circle && circle.number) {
      console.info(`Triggered circle build #${circle.number}`);
    } else {
      console.error(`Failed to trigger circle build for some reason:`);
      console.error(circle);
    }

    res.status(200);
    console.info(`HTTP 200: ${githubEvent} event`);
    res.send({ buildkite, circle } || {});
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
