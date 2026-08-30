open Core
open Mina_base
open Snark_params.Tick
open Fee_excess

let combine_checked_unchecked_consistent () =
  Quickcheck.test (Quickcheck.Generator.tuple2 gen gen) ~f:(fun (fe1, fe2) ->
      let fe = combine fe1 fe2 in
      let fe_checked =
        Or_error.try_with (fun () ->
            Test_util.checked_to_unchecked
              Typ.(typ * typ)
              typ
              (fun (fe1, fe2) -> combine_checked fe1 fe2)
              (fe1, fe2) )
      in
      match (fe, fe_checked) with
      | Ok fe, Ok fe_checked ->
          [%test_eq: t] fe fe_checked
      | Error _, Error _ ->
          ()
      | _ ->
          [%test_eq: t Or_error.t] fe fe_checked )

let () =
  let open Alcotest in
  run "Test fee excesses."
    [ ( "fee-excess"
      , [ test_case "Checked and unchecked behaviour consistent." `Quick
            combine_checked_unchecked_consistent
        ] )
    ]
