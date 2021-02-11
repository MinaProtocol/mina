# How to Run Integration Tests

1) pick an image to run the tests with
2) build `test_executive.exe` with the `integration_testnet` profile
3) run test executive, passing in the coda image selected in step 1
  3.a) it's recommended to run with the `--debug` flag when iterating on tests (this flag will pause testnet cleanup so that you can inspect a testnet after a test fails)
  3.b) it's also recommended to pipe log output through logproc with a filter to remove Debug and Spam logs be default (those log levels are very verbose and are intended for debugging test framework internals); use `tee` to store the raw output for later inspection

```sh
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe

CODA_IMAGE=... # pick a suitable (recent) "coda-daemon-puppeteered:XXX-develop-XXX" dockerhub
TEST=... # name of the test you want to run

dune build --profile=integration_testnet src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
test_executive cloud $TEST --coda-image=$CODA_IMAGE --debug | tee test.log | logproc -i inline -f '!(.level in ["Debug", "Spam"])'
```
