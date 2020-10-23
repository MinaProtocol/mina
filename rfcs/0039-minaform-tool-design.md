## Summary
[summary]: #summary

This rfc proposes a new tool dubbed "minaform" for reliably creating and managing QA nets and production deployments. Our existing setup is very hacky and requires knowledge of many tools to use effectively. The intention with minaform is to build a flexible enough tool that resolves major pain points with the existing setup, and standardizes a single tool for folks to learn/understand.

## Motivation
[motivation]: #motivation

Why are we doing this? What use cases does it support? What is the expected outcome?

The following issues with the existing system were reported by at least one person as "pain points" that consume time/debugging effort when deploying networks:

1) Production Networks vs. QA Nets
    - The process for deploying produciton testnets vs. qa nets has diverged in a few places and this means our day-to-day testing does not cover all of the services we need to deploy for public networks.
2) Determining network health is difficult/unclear/inconsistent
    - Some of this is addressed with more health checks in k8s and more metrics / better dashboards in grafana, but integrating the deployment tooling with all of those checks can help make it more foolproof.
3) No "uninstall" command / cleanup afterwards
    - Both the testnet terraform files and resources in the cluster end up hanging around more than neccessary. Needs additional tooling to clean up after itself.
4) Generating Genesis Proofs is slow/resource intensive/hard to predict
    - See proposal for how to pre-generate proofs in docker images
5) Hard to determine the correct docker tag from a given git SHA
    - Can be scripted to allow for a git tag or git SHA input, in addition to / in place of the docker tag.
6) Keys and other private info for deployment are not committed/shared with other team members
    - Addressed by https://github.com/MinaProtocol/coda-automation/issues/472
7) Incompatible helm/terraform versions
    - Can be addressed by 1) checking versioning before trying to use these tools and 2) bundling a canonical set of tools into a docker image
8) Incompatible helm/terraform changes
    - Addressed by moving the charts to the mina repo and explicitly releasing them. Terraform specifies an individual version of each chart to depend on and will fetch the released chart before deploys.
9) Helm string processing is inconsistent/hard
    - Now all charts are passing `helm lint` in the mina repo, and we can add `helm test` in the future as well.
10) Passing flags to the daemon process directly is difficult to debug/handle/manage
    -  Move to using daemon.json more and exposing all of these flags through the charts.

## Detailed design
[detailed-design]: #detailed-design

The design revolves around a new bash script, minaform, that can be bundled in a container alongside its dependencies.

### Minaform create-network

The first entrypoint to deploying a new network with minaform is the `create-network <testnet_name>` command which will create a new testnet folder based on the provided template (qa or prod templates to start, but more can be incorporated later), and then generate or download a set of keys + ledger to use with this new network. This templating system addresses Pain Point #1, but still needs cleanup afterwards. See `minaform delete-network <testnet_name>` for more on how to handle that.

With the templated terraform, minaform can now use the `coda-network` tool (aka carey's key service), to look for a set of keys and genesis block in google cloud for this testnet name, and if they do not exist then it will generate all of the neccessary keys for you, as well as the ledger itself.

Flags to the `create-network` command for `--generate-keys`, `--upload-keys`, and `--download-keys` allow you to force regeneration/re-upload of keys for easier testing and quick iteration on the key generation tooling. The default value of `true` for each of these makes it easy to share keys across O(1)  Labs employees who are collaborating on the same network (Pain Point #6).

Additional flags can be provided to the create-network command for changing the quantities of fish, whales, seeds, bots, etc.

The flag `--generate-image` will cause the tool to build a new image based on the provided one, but with the genesis ledger, proofs, and keys baked-in to reduce network startup time at the expense of this one-time step (Pain Point #4).

Two flags are availible to specify which version of the daemon to run, `--daemon-image` and `--daemon-git-sha` where daemon-git-sha calculates the image tag based on the given git tag (Pain Point #5). 

Once the network has been defined and set up, you can make manual changes to the terraform files to customize the new network, or just proceed to `minaform start <testnet_name>`.

### Minaform Start

The start command handles deploying the network and starting all containers / gcloud resources. `minaform start <testnet_name>` will start the given testnet on the default cluster, and provide a output to display the deployment progress. Keys will be uploaded to the cluster when the namespace is created, and then terraform resources will be deployed. If `--wait` is specified, the script will run `minaform watch <testnet_name>` once terraform is complete to watch for all of the nodes to become ready.

### Minaform Stop

The stop command handles destroying all resources for the given testnet, ideally using the existing terraform state and all of the same pararemeters so destroys can always happen smoothly. Will provide a `--force` flag to force terraform and other tooling to delete everything and clean up. This command closely matching the process for start/restart/etc. addresses pain point #3 and should make it easier to keep the cluster clean and easy.

### Minaform Restart

The restart command runs a `minaform stop` followed by `minaform start` and accepts the same flags as both start + stop.

### Minaform Upgrade

The upgrade command runs a terraform apply, to update the existing deployment with new changes. Ideally this should also provide more debugging flags to terraform and other tooling, and require user input to proceed so that the engineer deploying can understand what state will be lost (if any) in the process. Accepts the same flags as start/stop/restart.

### Minaform Watch

Addressing Pain Point #2 is the `minaform watch` command that will integrate with any scripts or tools we have right now (and write going forward) for monitoring network health. For grafana and google cloud it will just print links to their web dashboards. For kubernetes startup/liveness/readiness probes and tracking pod health there will be live statistics printed to the console. When new tooling is created for monitoring network health it should be added at least as a flag / subcommand of watch to allow for easy visibility.

### Minaform Help

The help page will link to this RFC as the initial docs and provide a list of all flags, commands, etc and their usage. Some flags like `--auto-approve` or `--force` are directly passed to terraform and the documentation for those flags should also be provided in the help for minaform. 

## Beyond the minaform tool

### Prod and QA templates

To properly provide consistent systems for key management and how to generate ledgers for a given network, the templates for production and qa networks will need to understand how to delegate stake to community members, where to download + source community member public keys, etc. As this will get complicated, for networks that use community member keys there may need to be a manual process interacting with `coda-network` or the existing hacky script in the `coda-network-integration` branch for that purpose. The priorities for key management are 1) flexible enough to manually create complex ledgers for specific networks, 2) straightforward and simple to deploy a network where we control all of the keys.

These templates are specifically designed to handle the #1 pain point and more clearly outline what a "normal" qa net should look like, as well as sharing as much infrastructure and process as possible with the production environment. The production template and associated files should include a README.md with exactly how this template becomes a production network deployment, especially if the key management or other pieces are not completely automated.

### Minaform Docker image

To address pain points #7 and #8, and to some extent the larger problem of how to make it easy for anyone, from anywhere, to deploy networks, we need a minaform docker image that can be bundled alongside all of its dependencies (nodejs for coda-network, some of our deb packages like generate-keypair, terraform, helm, most of mina-automation repo, and the helm charts themselves). These dependencies can then be handled by updates to the docker image, and anyone having trouble with version mismatches can mount their credentials into a docker container and get moving quickly.

In addition to use on any developer laptop, the docker image could be deployed directly into the cluster, google cloud shell, or a google cloud VM to allow for low-latency deployment to gcloud even from a high-latency network (hope that helps @bkase @mrmr1993 !).

## Drawbacks
[drawbacks]: #drawbacks

Generating genesis proofs on developer laptops means downloading snark keys from s3 or large dockerfiles from docker hub, and can be difficult on a poor connection. I still believe this is worth the effort/time compared to the cost of generating the same data on each node for hundreds of nodes, and will make it very clear which genesis ledger is in use on a given network.

If the templates always output the terraform files based on the templates, then we still end up with a lot of extra TF files around for old stopped networks. Could be handled with a flag to `minaform stop` and a dilligent process around when to clean up the old terraform. The alternative is to not save the post-template-execution terraform unless a flag is passed to explicitly save it for customization, which would discourage complex changes to the terraform config but would also make it harder to make complex changes when needed.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

* Why is this design the best in the space of possible designs?
* What other designs have been considered and what is the rationale for not choosing them?
* What is the impact of not doing this?

## Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* What parts of the design do you expect to resolve through the RFC process before this gets merged?
* What parts of the design do you expect to resolve through the implementation of this feature before merge?
* What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
