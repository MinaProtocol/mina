# Running Integration Tests

### Prerequisites Environment Setup

Note: this environment setup assumes that one is a member of o(1) labs and has access to organization infrastructure.  You will need an o(1) labs GCP account and AWS account.

1) Make sure you have the following critical tools installed
- terraform (https://www.terraform.io/downloads)
- google cloud SDK (https://cloud.google.com/sdk/docs/install)
- docker (https://docs.docker.com/get-docker/)
- kubernetes `kubectl` (https://kubernetes.io/docs/tasks/tools/)

2) Download the gcloud integration test API key.  Go to the API Credentials page (https://console.cloud.google.com/apis/credentials), find "Integration-tests log-engine" and copy the key for that onto your clipboard.  Run `export GCLOUD_API_KEY=<key>` and/or put it in one's bashrc or .profile.  Note that this API key is shared by everyone.

3) Download your key file for the `automated-validation` service account.  Go to the IAM Service Accounts page (https://console.cloud.google.com/iam-admin/serviceaccounts), click into the `automated-validation@<email domain>` page, click into the "Keys" section in the topbar, and create a new key (see picture).  Note that each individual should have their own unique key.  Download this key as a json file and save it to one's preferred path.  Run `export GOOGLE_CLOUD_KEYFILE_JSON=<path-to-service-account-key-file>` and/or put it in one's .bashrc or .profile. (Note: before you run this export command or set this environment variable, you may want to check if `GOOGLE_CLOUD_KEYFILE_JSON` is already in your path-- if it is then what you already have may work without further changes.)  the path to the automated-validation service account's keyfile will also be needed in step 4 of this setup.  

![automated-validation service account "Keys" tab](https://user-images.githubusercontent.com/3465290/112069746-9aaed080-8b29-11eb-83f1-f36876f3ac3d.png)

4) In addition to the above mentioned `GCLOUD_API_KEY` and `GOOGLE_CLOUD_KEYFILE_JSON`, ensure the following other environment variables are also properly set (preferably in in .bashrc or .profile.):
- `KUBE_CONFIG_PATH`.  this should usually be `~/.kube/config`
- the following AWS related vars, namely: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION=us-west-2`,
- vars relating to ocaml compilation

5) Run the following commands in order to log in to Google Cloud, and activate the service account for one's work machine.

```
gcloud auth login --no-launch-browser <gcloud-acct-login-username>
gcloud container clusters get-credentials --region us-west1 mina-integration-west1
kubectl config use-context gke_o1labs-192920_us-west1_mina-integration-west1
gcloud auth activate-service-account --key-file=<path-to-service-account-key-file>
```

When the service account is activated, one can run the integration tests.  However, in the course of using GCP, one may need to re-activate other accounts or set the context to use other clusters, switching away from the service account.  If one is getting authentication errors, then re-running the above commands to set the correct cluster and activate the service account will probably fix them.


6) OPTIONAL: Set the following aliases in one's .bashrc or .bash_aliases (note that aliases don't work if set in .profile):

```
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe
```

### Routine Test Run

1) Go to dockerhub [minaprotocol/mina-daemon](https://hub.docker.com/r/minaprotocol/mina-daemon/tags?page=1&ordering=last_updated) and pick an image to run the tests with.  When choosing an image, keep in mind the following tips.
- Usually, one should choose the most recent image from the branch one is currently working on.  
- Note that changes to the integration test framework itself do not make it into the daemon image, so one might as well just use the latest image off of the develop or compatible branch.  
- Generally use "-devnet" instead of "-mainnet" for testing although it usually won't make a difference.  

2) Build `test_executive.exe` with the `integration_tests` profile

3) Run `test_executive.exe`, passing in the mina image selected in step 1, and the name of the test one intends to run
- It's recommended to run with the `--debug` flag when iterating on the development of tests.  this flag will pause the destruction and cleanup of the generated testnet and associated terraform configuration files, so that those things can be inspected post-hoc
- It's also recommended to pipe log output through logproc with a filter to remove Debug and Spam logs be default (those log levels are very verbose and are intended for debugging test framework internals).  Use `tee test.log` to store the raw output into the file `test.log` so that it can be saved and later inspected.

```sh
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe

MINA_IMAGE=... # pick a suitable (recent) image from dockerhub or GCR
TEST=... # name of the test one wants to run

dune build --profile=integration_tests src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
test_executive cloud $TEST --mina-image=$MINA_IMAGE --debug | tee test.log | logproc -i inline -f '!(.level in ["Debug", "Spam"])'
```

4) OPTIONAL: In the event that the automatic cleanup doesn't work properly, one needs to do it manually.  Firstly, destroy what's on GCP with `kubectl delete namespace <namespace of test>`.  Then, `rm -r` the local testnet directory, which is in `./automation/terraform/testnets/`

### Notes on GCP namespace name
- Running the integration test will of course create a testnet on GCP.  In order to differentiate different test runs, a unique testnet namespace is constructed for each testnet.  The namespace is constructed from appending together the first 5 chars of the local system username of the person running the test, the short 7 char git hash, the test name, and part of the timestamp.
- the namespace format is: `it-{username}-{gitHash}-{testname}`.  for example: `it-adalo-3a9f8ce-payments`; user is adalovelace, git commit 3a9f8ce, running payments integration test
- GCP namespaces are limited to 53 characters.    This format uses up a fixed minimum of 22 characters, the integration tests will need a further number of those characters when constructing release names, and the longest release name for any resource happens to be "-block-producers" which is another 16 characters. As such the name of an integration test including dashes cannot exceed 15 characters


# Architecture

![Integration Test Framework General Architecture](https://user-images.githubusercontent.com/3465290/142286520-a73628ec-7604-4bc9-bf4e-f1b88b4d00a9.png)
*Integration Test Framework General Architecture.  edit this picture at: https://drive.google.com/file/d/1fN03qmTzpjibgu6TY4DGxJF9__P8xyK3/view?usp=sharing*

Any Integration test first creates a whole new testnet from scratch, and then runs test logic using that testnet in order to confirm and measure the performance of connectivity, functionality, or correct interactions between nodes

- control flow / data flow:
    - The integration test is kicked off by running the test_executive process, which is typically done from one's local machine but can really be run from anywhere (including from CI). the test_executive receives, as arguments, the test to run and the execution engine to run them on.
    - the test_executive process loads an integration test (specified by command argument), then uses the specified execution engine to spin up a testnet (whether it be on the cloud, a local network of VMs, or otherwise) in accordance with configurations specified within the integration test itself.
    - Once the testnet is fully established, the test_executive process can interact with nodes on the network and wait for various events to take place. It is able to send graphql queries to any of the nodes on the network, or further control the network (such as by stopping or starting nodes) through the use of the execution engine.
    - Wait conditions are the bread and butter of how tests are constructed in the test_executive. They can be written either as predicates on streams of structured log events received from the network, or as predicates on the global network state (which is automatically maintained by the framework).
        - The infrastructure engine streams logs from the nodes on the network back to the test_executive.  The test_executive will parse the logs to look for "structured log events", which are then internally routed within the test_executive process, and are consumed over subscriptions in order to implement wait conditions and update a network-wide view of the network's state.
    
- infrastructure engines: the writing of the test itself is abstracted away from the infrastructure that the test is running on.  one must pass in an initial argument specifying what infrastructure is to be used.  so far, the only implemented option is "cloud"
    - GCP cloud engine: using the cloud engine will spin up nodes on o(1)labs's GCP account.  this is currently the only implemented option
        - k8s
        - graphql ingress
        - stackdriver log subscriptions
    - local engine: using the local engine will spin up nodes as VMs or containers on one's local machine.  this is not yet implemented
    

# Code Structure

### Integration Test general purpose directories

- `src/app/test_executive/` — The integration tests themselves live here, along with the `test_executive.exe` entrypoint for executing them.
- `src/lib/integration_test_lib/` — Contains the core logic for integration test framework. This is where you will find the implementation of the DSL, including the event router, network state, and wait conditions. This library also contains the definition of the interfaces for execution engines and test definitions.

### GCP Cloud Engine implementation specific directories

- `src/lib/integration_test_cloud_engine/` — This library is the current implementation of the GCP cloud based execution engine, which deploys testnets in Gcloud's GKE environment.  As with any engine, it implements the interface defined in `Integration_test_lib`.  This execution engine leverages a good deal of our existing coda automation system.
- `automation/terraform/testnets` — During runtime, when using the GCP cloud engine, a directory of the same name as your testnet name will be created within this directory.  the terraform file which is `terraform apply`'d (ie main.tf.json) lives in here.
- `automation/terraform/modules/o1-integration` and `automation/terraform/modules/o1-testnet` — many terraform modules which are referenced by main.tf.json will be found in these directories
- `helm` — The helm charts (detailed yaml files) which fully specifies the configuration of all the nodes in GCP live here

![Integration Test Testnet creation process in GCP](https://user-images.githubusercontent.com/3465290/142287280-0a194a12-b0d0-4279-9393-f61b3f7053e0.png)
*Integration Test Testnet creation process in GCP.  edit this picture at: https://drive.google.com/file/d/16tcCW14SJyjVOrgdcVnt08pSep6RmRQ6/view?usp=sharing*

# Writing Tests

- To write a new integration test, create a new file in `src/app/test_executive/` and, conventionally, call it something like `*_test.ml`.  (Feel free to check out other tests in that directory for examples.)
- The new test must implement the `Test` interface found in `integration_test_lib/intf.ml` .  The two most important things to implement are the `config` struct and the `run` function.
    - `config` .  Most integration tests will use all the default values of `config` except for the number of block producers, the mina balance of each block producer, and the timing details of each block producer.  The integration test framework will create the testnet based on the highish level specifications laid out in this struct.
    - the `run` function contains all the test logic.  this function receives as an argument a struct `t` of type *dsl*, and a `network` struct of type *network*, both of which have their uses within the test.  There are a number of things that can be done in this function
        - **Interacting with nodes**.  Within `integration_test_lib/intf.ml` is a `Node` module which contains a number of function signatures which are implemented by all existing infrastructure engines.  These functions allow the integration test to interact with nodes in the testnet.
            - Puppeteer.  The `start` and `stop` functions use puppeteer to start and stop nodes, so that integration tests can test network resiliency.  (note: nodes will already by started at the beginning of tests, you do NOT need to manually start them)
            - Graphql.  functions like `get_peer_id` and `send_payment` will, under the hood, send a graphql query or mutation request to a specified node.  The test that one is writing may require one to write additional graphql client functions integration test side.  The new function must be defined in the `Node` module of intf.ml, and then implemented for each infrastructure engine.  For the cloud engine, graphql interactions are implemented in `integration_test_cloud_engine/kubernetes_network.ml`
        - **Waiting for conditions**.  the `wait_for` function can be used to wait for a number of different conditions, such as but not limited to:
            - initialization (the `run` function typically begins by waiting for all the block producers nodes in the testnet to initialize)
            - block produced
            - payment included in blockchain frontier
        - **Checking network state**.  The integration test framework keeps a special struct representing network state, which can be obtained by calling `network_state t`.  The members of this struct contain useful information, for example `(network_state t).blocks_generated` is simply an integer that represents the number of blocks generated.
            - Note that each call to `network_state t` returns a fresh and full struct whose value is computed eagerly, it is NOT lazy and does NOT return a pointer.  For example, if one calls `let ns = network_state t in ...`  , the value of `ns` is guaranteed to remain the same for the rest of the program (unless explicitly reassigned) EVEN if the actual network state changes in the meantime.  To obtain a fresh network state, one must make another explicit call to `network_state t`.


# Debugging Tests

<!-- - how to process test executive logs
    - logproc examples -->
- make sure to use the `--debug` flag so that the testnet doesn't automatically self-teardown after the test run
- if you suspect there may be infrastructure failures, or failures of the testnet to initialize
    - check the testnet status on the GCP console.  if there are errors about not enough CPU or something like that, then this is a problem of your GCP cluster not having enough resources, or there being too much resource contention
- how to debug terraform errors
    - terraform errors typically cause the integration test to fail quickly, without deploying anything to GCP.  
    - check the `main.tf` that the integration test generates.  there could be misconfigurations that have been passed into this file.
    - check the modules `o1-integration` and `o1-testnet`.  however unless you've changed these modules, or they have recently been changed by someone else, the error is unlikely to be here.
- how to find node logs
    - In the gcloud UI, from the [workloads page](https://console.cloud.google.com/kubernetes/workload), find your test run's namespace, click into a node (such as `test-block-producer1` ), then click into "Container logs".  This will take you to stack driver.  you can then peruse and search through the logs of the node.
<!--     - how to filter them (for kubectl, show logproc example, for gcloud ui, show stackdriver filter example) -->
- how to correlate expected structured events with logs.
    - structured log events are not an integration test construct, they are defined in various places around the protocol code.  For example, the  `Rejecting_command_for_reason` structured event is defined in `network_pool/transaction_pool.ml`.
    - The structured log events that matter to the integration test are in `src/lib/integration_test_lib/event_type.ml`.  The events integration-test-side will trigger based on logic defined in each event type's `parse` function, which parses messages from the logs, often trying to match for exact strings
- Please bear in mind that the nodes on GCP run the image that you link in your argument, it does NOT run whatever code you have locally.  Only that which relates to the test executive is run from local.  If you make a change in the protocol code, first this needs to be pushed to CI, where CI will bake a fresh image, and that image can be obtained to run on one's nodes.

# Exit codes

- Exit code `5` will be returned if some pods could not be found.
- Exit code `6` will be returned if `kubectl` exited with a non-zero code or a signal while attempting to retrieve logs.
- Exit code `7` will be returned if `kubectl` exited with a non-zero code or a signal while attempting to run a command in a container.
- Exit code `8` will be returned if `kubectl` exited with a non-zero code or a singal while attempting to run a node's `start.sh` script.
- Exit code `9` will be returned if `kubectl` exited with a non-zero code or a singal while attempting to run a node's `stop.sh` script.
