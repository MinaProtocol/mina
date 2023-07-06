let test_with_one_runtime_table_no_fixed_lookup_table () =
  let module Tick = Kimchi_backend.Pasta.Vesta_based_plonk in
  let module Circuit = Snarky_backendless.Snark.Run.Make (Tick) in
  let () =
    try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
  in
  let v = Circuit.Field.Constant.of_string "42" in
  let vv = Circuit.Field.Constant.of_string "1764" in
  let cs =
    Circuit.constraint_system ~input_typ:Circuit.Typ.unit
      ~return_typ:Circuit.Typ.unit (fun () () ->
        let square =
          (* Inputs of the computation, and we initialize to v *)
          let var_v = Circuit.exists Circuit.Field.typ ~compute:(fun () -> v) in
          (* We now add a multiplicate gate *)
          (* Outputs of the computation, and we make the  *)
          let var_prod =
            Circuit.exists Circuit.Field.typ ~compute:(fun () ->
                let lhs = Circuit.As_prover.read Circuit.Field.typ var_v in
                Circuit.Field.Constant.mul lhs lhs )
          in
          Circuit.with_label "mul gadget" (fun () ->
              let basic =
                Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                  (Basic
                     { l = (Circuit.Field.Constant.zero, var_v)
                     ; r = (Circuit.Field.Constant.zero, var_v)
                     ; o = (Circuit.Field.Constant.(negate one), var_prod)
                     ; m = Circuit.Field.Constant.one
                     ; c = Circuit.Field.Constant.zero
                     } )
              in
              Circuit.assert_ { annotation = Some __LOC__; basic } ;
              Circuit.assert_ { annotation = Some __LOC__; basic } ;
              Circuit.assert_ { annotation = Some __LOC__; basic } ;
              Circuit.assert_ { annotation = Some __LOC__; basic } ;
              (* Circuit.assert_ { annotation = Some __LOC__; basic } ; *)
              (* Circuit.assert_ { annotation = Some __LOC__; basic } ; *)
              (* Circuit.assert_ { annotation = Some __LOC__; basic } ; *)
              (* Circuit.assert_ { annotation = Some __LOC__; basic } ; *)
              (* Circuit.assert_ { annotation = Some __LOC__; basic } ; *)
              (* Circuit.assert_ { annotation = Some __LOC__; basic } ; *)
              var_prod )
        in

        let input_vv =
          Circuit.exists Circuit.Field.typ ~compute:(fun () -> vv)
        in
        Circuit.Field.Assert.equal square input_vv )
  in
  let gates = Tick.R1CS_constraint_system.finalize_and_get_gates cs in
  Printf.printf "Gates length: %d\n"
    (Kimchi_bindings.Protocol.Gates.Vector.Fp.len gates) ;
  Printf.printf "rows len: %d, primary input size: %d, aux input size: %d\n"
    (Tick.R1CS_constraint_system.get_rows_len cs)
    (Tick.R1CS_constraint_system.get_primary_input_size cs)
    (Tick.R1CS_constraint_system.get_auxiliary_input_size cs) ;
  let keypair = Tick.Keypair.create ~prev_challenges:0 cs in
  let vk = Tick.Keypair.vk keypair in
  let _domain = vk.domain in
  (* print_endline @@ string_of_int @@ vk.max_poly_size ; *)
  assert false

let () =
  let open Alcotest in
  run "Runtime table"
    [ ( "Scenarii"
      , [ test_case "One runtime table, no fixed lookup table" `Quick
            test_with_one_runtime_table_no_fixed_lookup_table
        ] )
    ]
