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
          - "CODENAMES=Focal,Bullseye"
          - "FROM_CHANNEL=Unstable"
          - "TO_CHANNEL=Experimental"
        image: codaprotocol/ci-toolchain-base:v3
        mount-buildkite-agent: true
        propagate-environment: true
```

Above definition one need to paste into steps edit box for given pipeline and then run from branch which contains this README.md (presumably develop). 

All list of available parameters: 

- DEBIANS - The comma delimited debian names. For example: `Daemon,Archive`. All available names are located in `buildkite/src/Constans/DebianPackage.dhall` files. Only CamelCase format is supported

- DOCKERS - The comma delimited docker names. For example: `Daemon,Archive`. All available names are located in `buildkite/src/Constans/Artifacts.dhall` files. Only CamelCase format is supported 

- CODENAMES - The Debian codenames `Bullseye,Focal`. All available names are located in `buildkite/src/Constans/DebianVersions.dhall`. Only CamelCase format is supported

- FROM_VERSION - The Source Docker or Debian version

- NEW_VERSION - The new Debian version or new Docker tag

- REMOVE_PROFILE_FROM_NAME - Should we remove profile suffix from debian name. For example from package name "mina-devnet-hardfork" it will generate name "mina-devnet"

- PROFILE                     The Docker and Debian profile (Standard, Lightnet)". All available profiles are located in `buildkite/src/Constants/Profiles.dhall` file. Only CamelCase format is supported

- NETWORK                     The Docker and Debian network (Devnet, Mainnet, Berkeley). All available profiles are located in `buildkite/src/Constants/Network.dhall` file. Only CamelCase format is supported

- FROM_CHANNEL                Source debian channel. By default: Unstable. All available channels  are located in `buildkite/src/Constants/DebianChannel.dhall` file. Only CamelCase format is supported

- TO_CHANNEL                  Target debian channel. By default: Unstable. All available profiles are located in `buildkite/src/Constants/DebianChannel.dhall` file. Only CamelCase format is supported

- PUBLISH                     The Publish to docker.io flag. If defined, script will publish docker do docker.io. Otherwise it will still resides in gcr.io


#### Examples 

Below examples focus only on environment variables values. We are omitting full pipeline setup.

##### Promoting Hardfork packages

We would like to promote all hardfork packages (archive node, daemon, rosetta) from unstable debian channel and gcr to devnet debian channel and dockerhub. We also want easy upgrade from old deamon debian to new one (we would like user experience to be smooth and only required command to update on user side should be `apt-get update mina-daemon`). That is why we want to strip `-hardfork` suffix from debian package. 
Pipeline with create 6 jobs for each Docker and Debian component separately.

```
  - "DOCKERS=Archive,Daemon,Rosetta"
  - "DEBIANS=Archive,Daemon,LogProc"
  - "REMOVE_PROFILE_FROM_NAME=1"
  - "PROFILE=Hardfork"
  - "NETWORK=Devnet"
  - "FROM_VERSION=3.0.0devnet-tooling-dkijania-hardfork-package-gen-in-nightly-b37f50e"
  - "NEW_VERSION=3.0.0-ddb6fc4"
  - "PUBLISH"=1
  - "CODENAMES=Focal,Bullseye"
  - "FROM_CHANNEL=Unstable"
  - "TO_CHANNEL=Devnet"
    
```

#### Promoting dockers form gcr to dockerhub

We want only to move dockers from gcr to dockerhub without changing version. Current implementation of pipeline is not user friendly so we need to still define `FROM_VERSION` and `TO_VERSION`. They should be equal.

```
  - "DOCKERS=Archive,Daemon,Rosetta"
  - "NETWORK=Devnet"
  - "FROM_VERSION=3.0.0-dc6bf78"
  - "NEW_VERSION=3.0.0-dc6bf78"
  - "CODENAMES=Focal,Bullseye"
  - "PUBLISH=1"
```