## Summary
[summary]: #summary

This rfc proposes a new tool dubbed "minaform" for reliably creating and managing QA nets and production deployments. Our existing setup is very hacky and requires knowledge of many tools to use effectively. The intention with minaform is to build a flexible enough tool that resolves major pain points with the existing setup, and standardizes a single tool for folks to learn/understand.

## Motivation
[motivation]: #motivation

The goal is to standardize community-oriented and internal qa networks with a simple tool to ensure that the process for creating and deploying a new testnet is coda-reviewed, documented, and standard across all deployment scenarios. As of this RFC, additional requirements for community members themselves or external partners to make use of this tooling is out-of-scope but the goal is that this implementation will be easier to maintain and extend as needs arise.

The following issues with the existing system were reported by at least one person as "pain points" that consume time/debugging effort when deploying networks:

1) Production Networks vs. QA Nets
    - The process for deploying production testnets vs. qa nets has diverged in a few places and this means our day-to-day testing does not cover all of the services we need to deploy for public networks.
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
    - Now all charts are passing `helm lint` in the mina repo, and we can add `helm test` in the future as well. Charts in the mina repo also allow for us to build dhall types and tooling around our charts, but that is out-of-scope for this RFC.
10) Passing flags to the daemon process directly is difficult to debug/handle/manage
    -  Expose command line flags genericly as a list of command line arguments in helm, allowing deployments to replace the default flags as needed and clearly specify them. These helm changes are just best-practices, and are also out-of-scope for this RFC.

## Detailed design
[detailed-design]: #detailed-design

One of the major design goals is to introduce a set of default terraform network configurations for qa and production that will be the starting point for all networks we deploy, and will be maintained with PR's and strict code review, while still allowing any further modification to fit the needs of any individual deployment, testing, or debugging effort. The design revolves around a new bash script, `minaform`, as well improvements to the existing coda-network tool, that can be bundled in a container alongside its dependencies for easy cross-platform use as soon as possible.  Why bash? See #rationale-and-alternatives

### Minaform create-network

The first entrypoint to deploying a new network with minaform is the `create-network <testnet_name>` command which will create a new testnet folder based on the provided example terraform testnet folder (with standard, well-commented, `qa` and `prod` example networks to start), and then generate or download a set of keys + ledger to use with this new network. This system of standardizing qa and prod networks, and building all future networks from this shared starting point  addresses Pain Point #1, but still needs cleanup when networks are no longer required. See `minaform delete-network <testnet_name>` for more on how to handle that.

With the example terraform, minaform can now use the `coda-network` tool (aka carey's key service), to look for a set of keys and genesis block in google cloud for this testnet name, and if they do not exist then it will generate all of the neccessary keys for you, as well as the ledger itself. In the initial implementation, this will be handled by the already ready to use but fairly hacky scripts `generate-keys-and-ledger.sh`, but as the coda-network tool becomes more fully featured then the sed+jq steps can be removed and minaform can interract directly with coda-network. The vision for coda-network includes commands for extending existing keysets or regenerating a genesis ledger with minor changes, so that once a network is created with minaform, any future edits to the keypairs or keysets or genesis ledger can be performed directly with coda-network.

Flags to the `create-network` command for `--generate-keys`, `--upload-keys`, and `--download-keys` allow you to force regeneration/re-upload of keys for easier testing and quick iteration on the key generation tooling. The default value of `true` for each of these makes it easy to share keys across O(1)  Labs employees who are collaborating on the same network (Pain Point #6).

The flag `--bake-image=true` will cause the tool to also run `minaform bake-image` to build a new docker image with all of the require network configuration and s3-cached files baked-in.

Two flags are availible to specify which version of the daemon to run, `--daemon-image` and `--daemon-git-sha` where daemon-git-sha calculates the image tag based on the given git tag (Pain Point #5). 

Additional flags can be provided to the create-network command for changing the quantities of fish, whales, seeds, bots, etc. These quantaties are provided at this stage so that the genesis ledger can be populated with proper accounts for these services.

Once the network has been defined and set up, you can always make manual changes to the terraform files to customize the new network, or just proceed to `minaform start <testnet_name>`. 

#### terraform.env

The configured docker image, git tag, deb package tag and the image generated by create-network (with deb package + keys + genesis proof) are stored alongside the default network configuration (prod or qa) in a `terraform.env` file and in `export TF_BLAH=blah` format so that those variables can be easily validated by the deploying engineer, and updated for each iteration of a testnet.  Google cloud storage paths to the keyfiles and ledger are also provided in this file for ease of use and visibility for anyone working with this network, and for use in `minaform get-network`.

Any additional common configuration parameters like log-level can also be added to the terraform environment in this way and exported as terraform environment variables so that those settings can even more easily be changed without touching the terraform. At any time as the default terraform testnets evolve we can use environment variables in more places identified to be commonly variable across networks.

Potentially this environment can be stored in GCP alonside keys and other things, while the coda-automation repo only houses the default network configs but I expect that providing a terraform file for each network even when the tf does not need to be updated will ensure that this solution remains compatible with the good parts of old workflows (terraform's flexibility) without the bad parts (hard to standardize when everything is flexible). If at some point in the future the vast majority of minaform networks have been deployed without edits to the tf then the defaults can be changed to only output a tf file for each network when an explicit flag is provided.

### Minaform get-network

The get-network command is meant to be used alongside create-network to easily allow engineers to collaborate on deployments of a testnet. `minaform get-network <testnet_name>` will use the terraform folder and `terraform.env` to download the keysets and genesis ledger for the given testnet so that you can start, stop, restart, or upgrade a network that you did not create.

### Minaform bake-image

The `bake-image <testnet_name> --git-sha <git-commit-sha>` command is a simple entrypoint for building a new image based on the provided one, but with the genesis ledger, proofs, and proving keys baked-in to reduce network startup time at the expense of this one-time step (Pain Point #4). This can be run on any existing network, and will replace the docker image, debian package, and google cloud storage urls in `terraform.env` to match the new image. Using a pre-baked images allows for all deployments to skip the generate-proof stage and avoids duplicate work of downloading and unpacking keys from s3, but `bake-image` should still make it easy to iterate on a network deployment when images have bugs and need to be updated.

### Minaform Start

The start command handles deploying the network and starting all containers / gcloud resources. `minaform start <testnet_name>` will start the given testnet on the default cluster, and provide a output to display the deployment progress. Keys will be uploaded to the cluster when the namespace is created, and then terraform resources will be deployed. If `--wait` is specified, the script will run `minaform watch <testnet_name>` once terraform is complete to watch for all of the nodes to become ready.

### Minaform Stop

The stop command handles destroying all resources for the given testnet, ideally using the existing terraform state and all of the same pararemeters so destroys can always happen smoothly. Will provide a `--force` flag to force terraform and other tooling to delete everything and clean up. This command closely matching the process for start/restart/etc. addresses pain point #3 and should make it easier to keep the cluster clean and easy.

### Minaform Restart

The restart command runs a `minaform stop` followed by `minaform start` and accepts the same flags as both start + stop.

### Minaform Upgrade

The upgrade command runs a terraform apply, to update the existing deployment with new changes. Ideally this should also provide more debugging flags to terraform and other tooling, and require user input to proceed so that the engineer deploying can understand what state will be lost (if any) in the process. Accepts the same flags as start/stop/restart.

### Minaform 

### Minaform Watch

Addressing Pain Point #2 is the `minaform watch` command that will integrate with any scripts or tools we have right now (and write going forward) for monitoring network health. For grafana and google cloud it will just print links to their web dashboards. For kubernetes startup/liveness/readiness probes and tracking pod health there will be live statistics printed to the console. When new tooling is created for monitoring network health it should be added at least as a flag / subcommand of watch to allow for easy visibility.

An issue has been raised that the logic for monitoring/validating the health of a network is orthogonal to deployment, which is understandable. The longer term plan of eventually transitioning to go makes the possible value of this sort of command much higher, and as such a bash implementation is less worthwhile. The grafana dashboard + gcp UI url for a given testnet can just as easily be returned by the start/restart/upgrade commands.

## Beyond the minaform tool

### Minaform Docker image

To address pain points #7 and #8, and to some extent the larger problem of how to make it easy for anyone, from anywhere, to deploy networks, we need a minaform docker image that can be bundled alongside all of its dependencies (nodejs for coda-network, some of our deb packages like generate-keypair, terraform, helm, most of mina-automation repo, and the helm charts themselves). These dependencies can then be handled by updates to the docker image, and anyone having trouble with version mismatches can mount their credentials into a docker container and get moving quickly.

In addition to use on any developer laptop, the docker image could be deployed directly into the cluster, google cloud shell, or a google cloud VM to allow for low-latency deployment to gcloud even from a high-latency network (hope that helps @bkase @mrmr1993 !).

## Drawbacks
[drawbacks]: #drawbacks

Generating genesis proofs on developer laptops means downloading snark keys from s3 or large dockerfiles from docker hub, and can be difficult on a poor connection. I still believe this is worth the effort/time compared to the cost of generating the same data on each node for hundreds of nodes, and will make it very clear which genesis ledger is in use on a given network.

If the templates always output the terraform files based on the templates, then we still end up with a lot of extra TF files around for old stopped networks. Could be handled with a flag to `minaform stop` and a dilligent process around when to clean up the old terraform. The alternative is to not save the post-template-execution terraform unless a flag is passed to explicitly save it for customization, which would discourage complex changes to the terraform config but would also make it harder to make complex changes when needed.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Why Bash?

* Key generation and upload are handled by bash scripts as of now so this will allow for quick iteration as hacky internals are removed, without changing the command line interface or the user experience. This design is intended to not introduce any additional tools to the process that we were not already committed to, so that after the minimum viable verison is in place we can re-evaluate if the system needs new tools.

Why is this design the best in the space of possible designs?

* To a point mentioned in the comments, bash has plenty of built-in support for properly parsing command-line arguments (see scripts/release-docker.sh in the mina repo for an example of handling that more properly), and very little needs to be done to glue terraform + coda-network together besides standardizing file paths and manipulating strings so the outputs of one tool properly match the inputs of another. A carefully written and commented bash script is the shortest path to a usable solution, and when the requirements for a solution exceed the plan outlined in this RFC we can just as easily continue from this point while rewriting in a compiled and typechecked language.

What other designs have been considered and what is the rationale for not choosing them?

* As I see it, the most reasonable non-bash language for this tooling is go, as the rest of the tooling used here (terraform, helm, prometheus, kubernetes, docker...) is availible via go libraries, go modules can handle the versioning of all dependencies (except coda-network), and the infrastructure team is already well-versed in go and can iterate quickly with it. Why not start in go? because as of today the main dependencies of this tool include a hacky bash script and coda-network, which are not in go, and invoking go tools like terraform and kubectl are the easiest part of the process. Bash is the simplest direction to proceed from here, but when the complexity of this tool exceeds a reasonable amount for bash then a go rewrite is easy and viable. To rewrite in go from that point can rely on the bash implementation for A/B testing, and as the plan B if the more complex tool `go`es wrong.

What is the impact of not doing this?

* Continuing with `auto-deploy.sh` means continued confusion over how to start when creating a new network, how to generate keys and a ledger, and how to customize terraform files. This will remain hard to maintain until we standardize the process and expectations around deploying testnets.

## Prior art
[prior-art]: #prior-art

Many proposals from the Conner era have tackled this design space, and a variety of python scripts used in the existing setup came out of those designs, and to some extent coda-network is a result as well. See https://github.com/MinaProtocol/mina/issues/4723 for an outline of the work achieved and what was left to be accomplished.

To that end, this concept was inspired by https://github.com/MinaProtocol/mina/issues/5768 and intends to achieve some of the listed design goals. The interface defined in this RFC can be extended to be community-friendly (by allowing easy configuration of google cloud and kubernetes credentials) but those features are out-of-scope for the initial implementation. Easier to iterate quickly on is a high priority, as is modularity (by still allowing direct use of terraform and direct interraction with coda-network).
 
## Unresolved questions
[unresolved-questions]: #unresolved-questions

* What parts of the design do you expect to resolve through the RFC process before this gets merged?
* What parts of the design do you expect to resolve through the implementation of this feature before merge?
* What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
