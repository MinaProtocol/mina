let () =
  Alcotest.run "graphql-server" [
    "schema", Schema_test.suite;
    "arguments", Argument_test.suite;
    "variables", Variable_test.suite;
    "introspection", Introspection_test.suite;
    "errors", Error_test.suite;
    (* "custom_errors", Custom_error_test.suite; *)
    "abstract", Abstract_test.suite;
    "directives", Directives_test.suite;
  ]
