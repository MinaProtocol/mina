# Testnet-Guardian Runbook

## Overview

A testnet guardian is the point of contact for anything engineering-related for an upcoming or a running testnet. Broadly speaking, a testnet guardian would perform/coordinate tasks involving building, testing and deploying testnet(s) for a release. They would also serve as a point-of-contact for protocol/product related queries from the community. This document describes all the tasks that a testnet guardian would perform during a release cycle and describes possible actions  in the case of events that affect the testnet. The role of a testnet guardian spans over a release cycle starting from code-freeze from the engineering team to the end of the release. The initial phase between code freeze and the public release is the QA phase where the testnet guardian will be responsible for building, deploying and testing internal QA-nets. On successful completion of the QA phase, the release phase starts during which the testnet guardian would support the release process and be the point of contact for the community.

## QA-net

The role of a testnet guardian for a release begins after the code-freeze. The following is the list of tasks that a testnet guardian would be responsible for:

### Release branch

Cut a release branch after the code-freeze(The naming convention for beta-testnets is `release/0.0.<release_number>-beta`. For example, `release/0.0.13-beta`)

### Build

The latest commit on the release branch should have successful builds for both macOS and Linux.
Go to the CI workflow for the specific commit and look for `build- macos` and `build-artifacts--testnet_postake_medium_curves` jobs for mac and linux builds respectively.

##### Update brew package
To update brew package,

1. Download the homebrew binary package from gcloud at the location specified in the `Copy artifacts to cloud` task in the `build-macOS` CI job. For example `gs://network-debug/382998/build/homebrew-coda.tar.gz`
2. Upload it to our public s3 bucket at `https://s3-us-west-2.amazonaws.com/packages.o1test.net`
3. In `coda.rb` in `CodaProtocol/homebrew-coda`,
        1. update the url with the location of the new tarball
        2. update the hash. The file containing the hash is uploaded to gcloud as well, for example `gs://network-debug/382998/build/homebrew-coda.tar.gz.sha256`
        3. increment the revision number

##### Update apt package
 1. Create an annotated tag for the latest commit on develop after code freeze. For example: `git tag -m "release 0.0.13" 0.0.13`
 2. push the tag `git push origin 0.0.13`
 3. Push the changes from develop on to master

##### Publish the location of the binaries
In addition to updating the brew and apt packages, publish the locations to the binaries on the discord channel `#QA-net details` channel for the rest of the team
1. macOS binary
2. linux binary
3. docker image
4. Name of the release branch

### Deploy

Deploy a QA-net (currently a 200-node network) with the new binaries. Ensure gossip logs are enabled by setting the daemon flags `log-snark-work-gossip`, `log-txn-pool-gossip`, and `log-received-blocks`.

Instructions for configuring and deploying a QA-net is roughly documented here: https://www.notion.so/codaprotocol/Testnet-deployment-notes-c1fbf8b8be9343b480f644c22d61ad85

### Test

After the QA-net is deployed, perform the following sanity-check:

##### Sanity check

1. Search for any crashes by querying the logs on StackDriver. The nodes are configured to restart upon crash for some of the known issues (#4295). Create issues for new ones.

2. Run `scripts/ezcheck.sh` to check if all the nodes are synced and have the same state hash at their best tips.

3. Query the logs to confirm that the nodes are creating and receiving blocks, transaction-pool diffs, and snark-pool diffs.
Some strings to look for: `Received a block`, `Received Snark-pool diff`, `Received transaction-pool diff`

4. Connect an external node to the network and check if it syncs
(TODO: to automate these checks)

Publish the peer ids of the seed nodes on `#QA-net details` channel for the rest of the team to connect to the QA-net.

##### Complete the challenges for the release

Connect to the QA-net from your machine and complete the protocol/product related challenges for the release. This is to test the features required for the challenges are working and also, may help the testnet guardian prepare for the kind of questions the community may have after the release.

##### Check docs

Verify that the docs are updated and user journeys are consistent with the release

##### Monitor the QA-net and report status

Monitor the health of the QA-net by checking the logs, grafana dashboard, telemetry and other tools. Check for
1. Crashes
2. Forks
3. Expected TPS
4. Blocks being produced consistently

Report the status of the network and testing to the rest of the team on `#qa-net-discussion` channel

On completing the QA-net phase successfully, let the infrastructure team know the same and tear down the QA-net before the release.

Easy peasy?

Maybe not, sometimes there could be unintended twists in the story and the testnet guardian might encounter issues along the way. Following is the list of possible situations and actions that the testnet guardian may take:

| | Event | Action | Criticality | Owner(s)|
|--|------|--------|-------------|--|
|1| Unsuccessful build jobs. (We shouldn't be merging hotfixes before all the CI jobs are successful).| Sometimes rerunning the build job fixes it. For example, at times docker upload fails and passes on rerun. But if there are other code/ci config related issues then the QA-net cannot continue until the issue is either reverted or fixed. In the case of a hotfix for issues encountered during QA-net, the fix should be reverted| Blocker| |
|2| Configuration/infra issues when deploying a QA-net | There are some troubleshooting notes in the notion document for the instructions to deploy a network. If that doesn't help then contact the any of the members listed in owners column for help | Blocker | Conner? Ahmad? Nathan?|
| 3| Unstable Testnet* (criteria for an unstable testnet is listed below)| Create an issue describing the observed behavior. The protocol team would need to investigate the problem and provide a hotfix before proceeding further with the release | Blocker | Aneesha? |
| 4| Errors when completing the challenges| Create an issue describing the observed behavior. Might have to exclude the challenge that causes the error if it cannot be patched and tested within the QA-net phase. Let the marketing and communications team know? | Major | Aneesha? Brandon? Christine?|
| 5 | Other errors/suspicious behavior observed when monitoring. These don't destabilize the testnet or affect the challenges | Create an issue describing the behavior | Minor | |
| 6 | Patch/hotfix | On receiving hotfix(es) on release and master(required for updating apt package) branch, destroy the existing   QA-net, repeat the [build](#build) and [deploy](#deploy) steps. Perform the [sanity checks](#sanity-check) and verify the fix | | |
| 7 | Hotfix doesn't work or causes other issues | Revert the fix and let the owners for the event type (for which the fix was issued) know |

*Criteria for an unstable testnet:

    1. Network forks 
    2. Blocks are not being created 
    3. Blocks/transactions/snark-work not being gossiped
    4. Transactions not getting included in a block
    5. Prover failures
    6. Other persistent crashes halting block production
    7. New nodes unable to join the network (either stuck in bootstrap or catchup)
    8. New nodes not syncing to the main chain and causing forks

## Release

On successful completion of the QA-net phase, the reliability team would spin up a testnet for the release. Testnet guardian would perform the [sanity checks](#sanity-check) on the new testnet.

The testnet guardian would also work with community relations and dev ops to be the community point of contact during working hours (being on top of and answering questions/help troubleshooting on discord)

Following is the list of events that could occur after the release

| | Event | Action | Criticality | Owner(s)|
|--|------|--------|-------------|--|
| 1| Issues preventing the users from completing the task | Since, we already tested all the challenges, either the user did the task incorrectly or in a different way that was missed by the engineering team. Usually, the community responds quickly to issues involving the challenges. Let the user know of the alternative way to finish the task. If the errors are real protocol/product bugs, create an issue and request the user to attach coda logs to the issue| Minor | |
| 2| Users' nodes crashing intermittently | If these are not one of the known bugs then create an issue for the same. Request the user to attach the latest crash report| Minor | |
| 3| Users' nodes crashing persistently | If it is for a specific user, might be that they did something differently when starting the node or their environment is not as expected. For example, connection timeouts (eventually causing the dameons to crash) between daemon and prover or daemon and snark workers could be because of resource constraints. If the cause is not determined, create an issue and request the user to attach the crash report | Major | Engineering team? |
|4| Unstable testnet | Create an issue for the protocol team to investigate. Coordinate with the owners of this event to discuss further actions based on the findings by the protocol team   | Critical | Aneesha? Brandon? Engineer investigating the issue?|

## Change Log

|version| description|
|-------|------------|
|0.0    | Initial version|
