# Display coverage summary

## display_summary.sh

Running `./display_summary.sh` will format the current coverage summary,
to highlight files containing code specific to the develop branch.

The result will be printed on stdout.

If the nix CI was already ran on the current checked out commit, the
coverage results will be recovered from the shared nix cache
(otherwise they can take a long time to build).

## Regular summary
The non post-processed summary is available at
```
$(nix build mina#mina_coverage --no-link --print-out-paths)/summary
```

Alternatively, at `./result/summary` after running `nix build mina#mina_coverage`.

## Full html coverage
The full html coverage report is also available at:
```
$(nix build mina#mina_coverage --no-link --print-out-paths)/html/index.html
```
