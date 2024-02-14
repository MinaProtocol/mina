ppx_version tests
=================

These are tests for the basic features of ppx_version.

There are "positive" tests, where the syntax should be accepted, and
"negative" tests, where the syntax should be rejected.

Disabling vendoring
-------------------

*** IMPORTANT ***

Before running these tests, *temporarily* comment out the
`vendored_dirs` clause in the dune file in the directory above this
one:

  ; (vendored_dirs test)

That clause prevents the ppx_version linter warnings from
taking effect in the negative tests, so that those tests fail.

Running the tests
-----------------

Run `make` to run all tests. There are also separate targets
"positive-tests" and "negative-tests".

The negative tests succeed if the dune build fails, but the failures
may occur for reasons other than the expected reasons. Ordinarily,
the test output is suppressed. By setting the VERBOSE environment
variable, the output is shown, in order to make sure the failures
are as expected.
