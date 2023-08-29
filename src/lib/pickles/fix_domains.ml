open Core_kernel
open Import

let zk_rows = 3

let rough_domains =
  let d = Domain.Pow_2_roots_of_unity 20 in
  { Domains.h = d }

let domains (type field) ?feature_flags
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = field)
    (Spec.ETyp.T (typ, conv, _conv_inv))
    (Spec.ETyp.T (return_typ, _ret_conv, ret_conv_inv)) main =
  let main x () = ret_conv_inv (main (conv x)) in

  let domains2 sys =
    let open Domain in
    (* Compute the domain requires for the lookup tables *)
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
            let range_check_table_used =
              range_check0 || range_check1 || foreign_field_mul || rot
            in
            let xor_table_used = xor in
            (if range_check_table_used then Int.pow 2 12 else 0)
            + (if xor_table_used then Int.pow 2 8 else 0)
            + ( if lookup then
                Impl.R1CS_constraint_system
                .get_concatenated_fixed_lookup_table_size sys
              else 0 )
            +
            if runtime_tables then
              Impl.R1CS_constraint_system
              .get_concatenated_runtime_lookup_table_size sys
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
