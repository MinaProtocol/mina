open Core_kernel

include Graphql_client_lib.Make (struct
  let address = "v1/graphql"

  let headers = String.Map.of_alist_exn []

  let preprocess_variables_string =
    String.substr_replace_all ~pattern:{|"constraint_"|}
      ~with_:{|"constraint"|}
end)
