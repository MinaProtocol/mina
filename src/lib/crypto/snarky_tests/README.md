# Snarky Tests

To run the tests, you must have [alcotest](https://github.com/mirage/alcotest) and [qcheck](https://github.com/c-cube/qcheck) installed. Then you can simply run:

```
$ ALCOTEST_COLOR=always dune test .
```

> Note: once we move to Alcotest 1.7.0 we won't have to pass `ALCOTEST_COLOR=always` anymore.

To run a single test:

```
$ dune exec -- src/lib/crypto/snarky_tests/test.exe 'boolean circuit'
```
