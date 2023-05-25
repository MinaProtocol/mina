# GITHUB Auto sync tool

Aim of this project is to satisfy needs for automatic branch synchronization between important branches in github. So far this is manual process of detecting changes between branches, Pull requests creation, checking if there is no merge conflicts and pushing changes to target branch.
This tool automate this process. It is possible to deploy project to google cloud function module.

## Business logic

### Requirements:

For MVP we want only merge conflicts detection. 

- [x] There should NOT be a PR created if there is no merge conflicts.
- [x] There should be a PR created with assignee list tagged who should fix the PR.
- [x] Program should detect changes immediately and perform merging attempt. 
- [ ] There should be a solution for updating already existing PR with new conflicting changes
- [ ] In future we maybe would like to attach some small buildkite pipeline for testing purposes (TBD)

### Design

Program mainly operates on Github REST API. It creates a thin layer of configuration and logic on top of python library (PyGithub).

It is prepared to receive github webhook payload json on new commit to specified branches and to be deployed in google cloud function

#### Basic flow:
- Perform diff between incoming source and target branches
- Create branch containing commits

    a) If branch already exists, push this commit and tag assigners that there was yet another commit check if there are merge conflicts
    
    b) if there are conflicts : create pr from temp branch to target branch. Add proper description. Add assigners which should fix the pr
    
    c) if there are not conflicts : start buildkite pipeline (TBD) to verify changes. If they passes merge pr and exit

##### Examples:

###### No conflict 

![No conflict](./docs/res/CASE1.jpg)

###### Conflict

![Conflict](./docs/res/CASE2.jpg)

###### Update sync branch while on conflict

![Update branch while conflict](./docs/res/CASE3.jpg)

# Configuration

Configuration is defined as module in `./github_autosync/gcloud_entrypoint/lib/config.py`

Below more detailed description of each section

## Branches

Controls relation between branches. Dictionary key is a branch name on which change we will try to merge to branch with name as value.

For example tuple master -> develop: 

If there is a new commit on master branch, program will attempt to merge new changes to develop branch. We can have more than one branch mapping: 
```
branches = dict(
    master = 'develop',
    develop = 'featureA'
)
```

## Github

Github access settings. Points to user (or organization), repository and access token. Access token can be classic or fine-grained. However if latter is used, then an issue can be encountered during e2e test run, since it uses Graphql Api. 
Implementation of fine-grained is still TBD: (https://github.blog/2022-10-18-introducing-fine-grained-personal-access-tokens-for-github/)

Token need to have permission to:
- list prs,
- list branches,
- create new branch,
- create new pr,
- delete branch,
- merge branch.

Example:

```
github = {
    "token": "....",
    "username": "dkijania",
    "repo": "myproject",
    "new_branch_name_format": "sync-{source_branch}-with-{target_branch}"
}
```

## Pull Request Configuration

Specific settings for PR creation (if there is necessity to do it based on branch merge conflict).

example:

```
pr = {
    "title_prefix": "[Branches auto sync failure] ",
    "assignees": ["dkijania"],
    "body_prefix": "This is auto-generated PR in order to solve merge conflicts between two branches.",
    "draft": 'false',
    "labels": ["auto-sync"]
}
```

## Buildkite (TBD)


# CLI

For debugging purposes cli entry point can be used. All it need is a properly configured program and payload.json file.

Example:

```
python3 github_autosync payload.json 
```

Where `payload.json` is a webhook event json payload.

**WARNING:**

**Changes made in such run will also be persistent (as running tool on gcloud)**


# Tests

## Setup

Test run requires below setup:

- Classic Github Token need to be used,
- Sample github project need to be created. Alternatively existing project (https://github.com/dkijania/webhook_test) can be used. Please contact dariusz@o1labs.org in order to gain access.
- Set environment variables:
  - WEBHOOK_APP_USER - owner of repo
  - WEBHOOK_APP_REPO - repository name
  - WEBHOOK_APP_TOKEN - classic token with access to above repo

## Run

```
 make run-tests
```

### Warnings during test execution

Test execution may produce warnings which are related to known issue:
https://github.com/PyGithub/PyGithub/issues/1372

They manifest as warnings in console or log output similar to:

```
sys:1: ResourceWarning: unclosed <ssl.SSLSocket fd=4, family=AddressFamily.AF_INET, type=SocketKind.SOCK_STREAM, proto=6, laddr=('192.168.0.140', 36024), raddr=('140.82.121.6', 443)>
sys:1: ResourceWarning: unclosed <ssl.SSLSocket fd=3, family=AddressFamily.AF_INET, type=SocketKind.SOCK_STREAM, proto=6, laddr=('192.168.0.140', 36010), raddr=('140.82.121.6', 443)>
```

# GCloud Deployment

## Setup

Your gcloud account need to be configured. Please run:

```
$ gcloud auth login
```

and follow instructions if you are not logged to gcloud cli.

### Set env variables

```
$export WEBHOOK_APP_USER=owner of repo
$export WEBHOOK_APP_REPO=repository name
$export WEBHOOK_APP_TOKEN=classic token or fine grained token
$export WEBHOOK_APP_GITHUB_SECRET=webhook github secret
```

#### Notes on WEBHOOK_APP_GITHUB_SECRET
Github secret can be acquired from existing gcloud storage:

`https://console.cloud.google.com/security/secret-manager/secret/WEBHOOK_APP_GITHUB_SECRET/versions?project=o1labs-192920`

Usually we don't want to update it as this leads to required update of github secret token in github.
However, if there is a such necessity below steps will help perform such operation:

1. Generate token locally
```
$ openssl rand -hex 20
```

2. Copy token to github webhook event settings:

Follow instructions on: https://docs.github.com/en/webhooks-and-events/webhooks/securing-your-webhooks#setting-your-secret-token

3. Set environment variable
```
$set WEBHOOK_APP_GITHUB_SECRET={output from command 1.}
```

#### Notes on WEBHOOK_APP_TOKEN

Valid github token (classic or fine-grained) should have following permissions: 
- list prs,
- list branches,
- create new branch,
- create new pr,
- delete branch,
- merge branch.

Both fine-grained tokens or classic are acceptable. However when running tests please ensure that classic token is used as we are 
using github graphql instance (for creating commits) which is not supporting fine-grained token yet

### Run 

In order to deploy application to gcloud first run:

```
make deploy
```

This deploys to https://console.cloud.google.com/functions/details/us-central1/AutoSyncBranches

### Post deploy checks

Please ensure that proper permissions are set for cloud function. Github webhook need below permission:

| Role  | Group |
|-------|-------|
| Cloud Functions Invoker | allUsers |

**Note:**

While generally it is unsafe to allow all users invoke cloud function, we have a safe guard in form of validating response with github secret.
