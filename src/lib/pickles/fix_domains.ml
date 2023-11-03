open Core_kernel
open Import

let zk_rows = 3

let rough_domains =
  let d = Domain.Pow_2_roots_of_unity 20 in
  { Domains.h = d }

let domains (type field gates) ?feature_flags
    (module Impl : Snarky_backendless.Snark_intf.Run
      with type field = field
       and type R1CS_constraint_system.t = ( field
                                           , gates )
                                           Kimchi_backend_common
                                           .Plonk_constraint_system
                                           .t )
    (Spec.ETyp.T (typ, conv, _conv_inv))
    (Spec.ETyp.T (return_typ, _ret_conv, ret_conv_inv)) main =
  let main x () = ret_conv_inv (main (conv x)) in

  let domains2 sys =
    let open Domain in
    (* Compute the domain required for the lookup tables *)
    let lookup_table_length_log2 =
      match feature_flags with
      | None ->
          0
      | Some feature_flags ->
          let { Pickles_types.Plonk_types.Features.range_check0
              ; range_check1
              ; foreign_field_add =
                  _
                  (* Does not use lookup tables, therefore we do
                     not need in the computation *)
              ; foreign_field_mul
              ; xor
              ; rot
              ; lookup
              ; runtime_tables
              } =
            feature_flags
          in
          let combined_lookup_table_length =
            let range_check_table_used = range_check0 || range_check1 || rot in
            let range_check_table_used_again =
              (* FIXME: This is a hack around a bug in proof-systems. *)
              foreign_field_mul
            in
            let xor_table_used = xor in
            (if range_check_table_used then Int.pow 2 12 else 0)
            + (if range_check_table_used_again then Int.pow 2 12 else 0)
            + (if xor_table_used then Int.pow 2 8 else 0)
            + ( if lookup then (
                Kimchi_backend_common.Plonk_constraint_system
                .finalize_fixed_lookup_tables sys ;
                Kimchi_backend_common.Plonk_constraint_system
                .get_concatenated_fixed_lookup_table_size sys )
              else 0 )
            +
            if runtime_tables then (
              Kimchi_backend_common.Plonk_constraint_system
              .finalize_runtime_lookup_tables sys ;
              Kimchi_backend_common.Plonk_constraint_system
              .get_concatenated_runtime_lookup_table_size sys )
            else 0
          in

          Int.ceil_log2 (combined_lookup_table_length + zk_rows + 1)
    in
    let public_input_size =
      Set_once.get_exn
        (Impl.R1CS_constraint_system.get_public_input_size sys)
        [%here]
    in
    let rows =
      zk_rows + public_input_size + Impl.R1CS_constraint_system.get_rows_len sys
    in
    { Domains.h =
        Pow_2_roots_of_unity Int.(max lookup_table_length_log2 (ceil_log2 rows))
    }
  in
  domains2 (Impl.constraint_system ~input_typ:typ ~return_typ main)
