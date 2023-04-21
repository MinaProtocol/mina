open Core_kernel
open Mina_base.Transaction_status

let of_string_to_string_roundtrip () =
  List.iter Failure.all ~f:(fun failure ->
      [%test_eq: (Failure.t, string) Result.t]
        Failure.(of_string (to_string failure))
        (Ok failure) )
