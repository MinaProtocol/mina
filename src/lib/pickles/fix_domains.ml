open Core_kernel
open Import

let domains (sys : _ Zexe_backend_common.Plonk_constraint_system.t) : Domains.t
    =
  let open Zexe_backend.R1CS_constraint_system in
  let open Domain in
  let rows = List.length sys.rows_rev in
  let public_input_size = sys.public_input_size in
  (* TODO: h should maybe be ceil_log2 (rows + public_input_size + 1) *)
  { h= Pow_2_roots_of_unity Int.(ceil_log2 rows)
  ; x= Pow_2_roots_of_unity (Int.ceil_log2 (1 + public_input_size)) }

let rough_domains : Domains.t =
  let d = Domain.Pow_2_roots_of_unity 20 in
  {h= d; x= Pow_2_roots_of_unity 6}

let domains (type field a)
    (module Impl : Snarky_backendless.Snark_intf.Run
      with type field = field
       and type R1CS_constraint_system.t = ( a
                                           , field )
                                           Zexe_backend_common
                                           .Plonk_constraint_system
                                           .t) (Spec.ETyp.T (typ, conv)) main =
  let main x () : unit = main (conv x) in
  domains (Impl.constraint_system ~exposing:[typ] main)
