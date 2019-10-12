let () =
  Lint_syntax.register () ;
  Ppxlib.Driver.standalone ()
