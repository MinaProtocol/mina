# How to Run Integration Tests

## Prerequisites

1) ensure the following environment variables are properly set if not already: `GCLOUD_API_KEY` (relating to the gcloud service account used in step 2), `KUBE_CONFIG_PATH`, any other vars relating to Google cloud access, vars relating to AWS access, vars relating to ocaml compilation.

2) log in to Google Cloud, with the correct cluster, and activate the service account

`gcloud auth login --no-launch-browser <personal login name>`
`gcloud container clusters get-credentials --region us-west1 mina-integration-west1`
`gcloud auth activate-service-account <name of service account> --key-file=<path to key file>`

If, in the course of other development, one switches to a separate account, one may need to run the last line again in order to switch back to the service account.

3) OPTIONAL: set the following aliases in one's .bashrc or .bash_aliases (note that aliases don't work if set in .profile):

`alias test_executive=./_build/default/src/app/test_executive/test_executive.exe`
`alias logproc=./_build/default/src/app/logproc/logproc.exe`



## Routine Test Run

1) go to mina protocol's dockerhub and pick a `coda-daemon-puppeteered` image to run the tests with.  usually, this image should be a recent image on the same branch as one is currently on.

2) build `test_executive.exe` with the `integration_tests` profile

3) run `test_executive.exe`, passing in the coda image selected in step 1, and the name of the test one intends to run
  
  3.a) it's recommended to run with the `--debug` flag when iterating on the development of tests.  this flag will pause the destruction and cleanup of the generated testnet and associated terraform configuration files, so that those things can be inspected post-hoc
  
  3.b) it's also recommended to pipe log output through logproc with a filter to remove Debug and Spam logs be default (those log levels are very verbose and are intended for debugging test framework internals); use `tee` to store the raw output for later inspection

```sh
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe

CODA_IMAGE=... # pick a suitable (recent) "coda-daemon-puppeteered:XXX-develop-XXX" dockerhub
TEST=... # name of the test you want to run

dune build --profile=integration_tests src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
test_executive cloud $TEST --coda-image=$CODA_IMAGE --debug | tee test.log | logproc -i inline -f '!(.level in ["Debug", "Spam"])'
```

4) OPTIONAL: In the event that the automatic cleanup doesn't work properly, one needs to do it manually.  Firstly, destroy what's on GCP with `kubectl delete namespace <namespace of test>`.  Then, delete the local testnet directory, which is in `./automation/terraform/testnets/`