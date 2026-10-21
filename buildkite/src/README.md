# Buildkite CI

This folder contains all dhall code which is a backbone for our CI related code for buildkite.

> **New here?** If you want to *add* a job, start with
> [`../HOWTO-add-a-job.md`](../HOWTO-add-a-job.md). This README is a system
> reference (modes, stages, filters, entrypoints) — it explains how the
> pipeline is wired, not how to write a job for it. To run a job locally
> see [`../local/README.md`](../local/README.md).

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
        image: europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4
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
(non-important attributes were omitted)
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

