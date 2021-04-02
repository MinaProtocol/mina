# How to Run Integration Tests

## Prerequisites

1) Ensure the following environment variables are properly set if not already: `GCLOUD_API_KEY` (relating to the gcloud service account used in step 2), `KUBE_CONFIG_PATH`, any other vars relating to Google cloud access, vars relating to AWS access, vars relating to ocaml compilation.

2) Log in to Google Cloud, with the correct cluster, and activate the service account

`gcloud auth login --no-launch-browser <personal login name>`
`gcloud container clusters get-credentials --region us-west1 mina-integration-west1`
`gcloud auth activate-service-account <name of service account> --key-file=<path to key file>`

If, in the course of other development, one switches to a separate account, one may need to run the last line again in order to switch back to the service account.

3) OPTIONAL: Set the following aliases in one's .bashrc or .bash_aliases (note that aliases don't work if set in .profile):

`alias test_executive=./_build/default/src/app/test_executive/test_executive.exe`
`alias logproc=./_build/default/src/app/logproc/logproc.exe`



## Routine Test Run

1) Go to mina protocol's dockerhub and pick a `coda-daemon-puppeteered` image to run the tests with.  usually, this image should be a recent image on the same branch as one is currently on.

2) Build `test_executive.exe` with the `integration_tests` profile

3) Run `test_executive.exe`, passing in the coda image selected in step 1, and the name of the test one intends to run
  
  3.a) It's recommended to run with the `--debug` flag when iterating on the development of tests.  this flag will pause the destruction and cleanup of the generated testnet and associated terraform configuration files, so that those things can be inspected post-hoc
  
  3.b) It's also recommended to pipe log output through logproc with a filter to remove Debug and Spam logs be default (those log levels are very verbose and are intended for debugging test framework internals); use `tee` to store the raw output for later inspection

```sh
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe

CODA_IMAGE=... # pick a suitable (recent) "coda-daemon-puppeteered:XXX-develop-XXX" dockerhub
TEST=... # name of the test one wants to run

dune build --profile=integration_tests src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
test_executive cloud $TEST --coda-image=$CODA_IMAGE --debug | tee test.log | logproc -i inline -f '!(.level in ["Debug", "Spam"])'
```

4) OPTIONAL: In the event that the automatic cleanup doesn't work properly, one needs to do it manually.  Firstly, destroy what's on GCP with `kubectl delete namespace <namespace of test>`.  Then, delete the local testnet directory, which is in `./automation/terraform/testnets/`

## Notes on GCP namespace name

Running the integration test will of course create a testnet on GCP.  In order to differentiate different test runs, a unique testnet namespace is constructed for each testnet.  The namespace is constructed from appending together the first 5 chars of the local system username of the person running the test, the short 7 char git hash, the test name, and part of the timestamp.

format is: ``it-{username}-{gitHash}-{testname}`

ex: ``it-adalo-3a9f8ce-block-prod`; user is adalovelace, git commit 3a9f8ce, running block production test

GCP namespaces are limited to 53 characters.    This format uses up a fixed minimum of 22 characters, the integration tests will need a further number of those characters when constructing release names, and the longest release name for any resource happens to be "-block-producers" which is another 16 characters. As such the name of an integration test including dashes cannot exceed 15 characters
