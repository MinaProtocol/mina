  $ env -u OCAMLRUNPARAM jbuilder runtest simple
           run alias simple/runtest (exit 2)
  (cd _build/default/simple && .foo_simple.inline-tests/run.exe)
  Fatal error: exception File "simple/.foo_simple.inline-tests/run.ml", line 1, characters 10-16: Assertion failed
  [1]

  $ dune runtest missing-backend
  File "missing-backend/dune", line 3, characters 1-15:
  3 |  (inline_tests))
       ^^^^^^^^^^^^^^
  Error: No inline tests backend found.
  [1]

  $ dune runtest too-many-backends
  File "too-many-backends/dune", line 17, characters 1-15:
  17 |  (inline_tests)
        ^^^^^^^^^^^^^^
  Error: Too many independent inline tests backends found:
  - "backend_tmb1" in _build/default/too-many-backends
  - "backend_tmb2" in _build/default/too-many-backends
  [1]

  $ dune runtest many-backends-choose
           run alias many-backends-choose/runtest
  backend_mbc1

  $ dune runtest dune-file
  (dune
   2
   ((inline_tests.backend
     1.0
     ((runner_libraries (str))
      (flags
       (inline-test-runner
        %{library-name}
        -source-tree-root
        %{workspace_root}
        -diff-cmd
        -))
      (generate_runner
       (progn
        (echo "let () = print_int 41")
        (echo "\n")
        (echo "let () = print_int 42")
        (echo "\n")
        (echo "let () = print_int 43;;")))))))
           run alias dune-file/runtest
  414243
