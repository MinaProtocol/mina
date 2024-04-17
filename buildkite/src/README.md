# Buildkite CI

This folder contains all dhall code which is an backbone for our CI related code for buildkite.

# Structure

Buildkite CI consist of two layers dhall and scripts. Basically idea is to use [Dhall](https://dhall-lang.org/) to create pipeline configuration in yaml. Pipeline configuration defines execution setup for scripts under `buildkite/scripts` folder. All Dhall files can be find in `buildkite/src` files. Each individual job is placed in `buildkite/src/Jobs` folder. Then `Prepare.dhall` file generates jobs collection based on content of `buildkite/src/Jobs`. Another important module is `Monorepo.dhall` which selects which jobs are meant to run (based on `BUILDKITE_PIPELINE_MODE` env in pipeline definition)

## Entrypoints

### Prepare and Monorepo modules

Main entrypoint for dhall project is a `Prepare.dhall` file which starts CI utilizing buildkite pipeline like below:

```
steps:
  - commands:
      - "dhall-to-yaml --quoted <<< './buildkite/src/Prepare.dhall' | buildkite-agent pipeline upload"
    label: ":pipeline:"
    agents:
       size: "generic"
    plugins:
      "docker#v3.5.0":
        environment:
          - BUILDKITE_AGENT_ACCESS_TOKEN
          - "BUILDKITE_PIPELINE_MODE=PullRequest"
          - "BUILDKITE_PIPELINE_STAGE=Test"
          - "BUILDKITE_PIPELINE_FILTER=AllTests"
        image: codaprotocol/ci-toolchain-base:v3
        mount-buildkite-agent: true
        propagate-environment: true

```

You can notice three environment variables which controls how CI works:

#### BUILDKITE_PIPELINE_MODE

Possible values: PullRequest|Stable

It controls job selection mode. If `PullRequest` is chosen then jobs will be selected based on changes made in PR. Each job has a configuration (namely `dirtyWhen` attribute) which allows to configure it individually.

However, if you choose `Stable` then all defined jobs should be run. This mode is usually used in nightly and stable pipelines

#### BUILDKITE_PIPELINE_STAGE

Possible values: UserDefined

User defined value which describe current pipeline chunk of jobs to be executed. Staging is introduced to allow specific pipeline configuration in which we would like to block certain set of jobs which are heavy and long. For instance, let us design our pipeline to have 3 stages :

- fast jobs only - which provides quick feedback for developer regarding linting
- long jobs - depends on fast jobs only stage and requires that all jobs are green before running any heavy job 
- coverage gathering - which gathers coverage artifacts and uploads it to coveralls.io

To reach above pipeline configuration below configuration can be provided:
(non important attributes where omitted)
```
steps:
  - commands:
    ...
          - "BUILDKITE_PIPELINE_MODE=Stable"
          - "BUILDKITE_PIPELINE_STAGE=Test"
          - "BUILDKITE_PIPELINE_FILTER=FastOnly"
   ...
  - wait
  - commands:
    ...
          - "BUILDKITE_PIPELINE_MODE=Stable"
          - "BUILDKITE_PIPELINE_STAGE=Test"
          - "BUILDKITE_PIPELINE_FILTER=LongAndVeryLong"
    ...
  - wait
  - commands:
    ...
          - "BUILDKITE_PIPELINE_MODE=Stable"
          - "BUILDKITE_PIPELINE_STAGE=TearDown"
          - "BUILDKITE_PIPELINE_FILTER=TearDownOnly"
    ...
```

#### BUILDKITE_PIPELINE_FILTER

Possible values: FastOnly,Long,LongAndVeryLong,TearDownOnly,ToolchainsOnly,AllTests,Release

Pipeline filter env variable a mechanism to limit collection of jobs to be run in single pipeline run. This is done by using Tag and Filter structures. Tag can be used in Job definition for example:

```
in  Pipeline.build
      Pipeline.Config::{
        spec = JobSpec::{
        , dirtyWhen = [
            ...
          ]
        , path = "Lint"
        , name = "Fast"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
        }
      , steps = [ .. ]
      }

```

Above job definition defines Job which is tagged by Fast and Lint tags. In the next step you can define Filter variant value which fetch only Fast and Lint tags:

```
let tags: Filter -> List Tag.Type = \(filter: Filter) -> 
  merge {
    QuickLints = [ Tag.Type.Fast , Tag.Type.Fast ]
    ....
  } filter

```

Above QuickLints variant can be used as a value for `BUILDKITE_PIPELINE_FILTER`

### Promote Package

Another dhall entrypoint which can be used as separate utility pipeline is PromotePackage module located in `buildkite/src/Entrypoints/PromotePackage.dhall`. As a UX improvement we provided `buildkite/scripts/run_promote_build_job.sh` job which converts env variables into dhall structures greatly simplifying pipeline definition:

```
steps:
  - commands:
      - "./buildkite/scripts/run_promote_build_job.sh | buildkite-agent pipeline upload"
    label: ":pipeline: run promote dockers build job"
    agents:
       size: "generic"
    plugins:
      "docker#v3.5.0":
        environment:
          - BUILDKITE_AGENT_ACCESS_TOKEN
          - "DOCKERS=Archive,Daemon"
          - "REMOVE_PROFILE_FROM_NAME=1"
          - "PROFILE=Hardfork"
          - "NETWORK=Devnet"
          - "FROM_VERSION=3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e"
          - "NEW_VERSION=3.0.0fake-ddb6fc4"
          - "CODENAMES=Focal,Buster,Bullseye"
          - "FROM_CHANNEL=Unstable"
          - "TO_CHANNEL=Experimental"
        image: codaprotocol/ci-toolchain-base:v3
        mount-buildkite-agent: true
        propagate-environment: true
```

All list of available parameters: 

- DEBIANS - The comma delimitered debian names. For example: `Daemon,Archive`

- DOCKERS - The comma delimitered docker names. For example: `Daemon,Archive`

- CODENAMES - The Debian codenames `Bullseye,Buster,Focal`

- FROM_VERSION - The Source Docker or Debian version

- NEW_VERSION - The new Debian version or new Docker tag

- REMOVE_PROFILE_FROM_NAME - Should we remove profile suffix from debian name. For example 

- PROFILE                     The Docker and Debian profile (Standard, Lightnet)"

- NETWORK                     The Docker and Debian network (Devnet, Mainnet, Berkeley)"

- FROM_CHANNEL                Source debian channel"

- TO_CHANNEL                  Target debian channel"

- PUBLISH                     The Publish to docker.io flag. If defined, script will publish docker do docker.io. Otherwise it will still resides in gcr.io
