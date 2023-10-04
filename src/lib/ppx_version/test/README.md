ppx_version tests
=================

These are tests for the basic features of ppx_version.

There are "positive" tests, where the syntax should be accepted, and
"negative" tests, where the syntax should be rejected.

Run `make` to run all tests. There are also separate targets
"positive-tests" and "negative-tests".

The negative tests succeed if the dune build fails, but the failures
may occur for reasons other than the expected reasons. Ordinarily,
the test output is suppressed. By setting the VERBOSE environment
variable, the output is shown, in order to make sure the failures
are as expected.
