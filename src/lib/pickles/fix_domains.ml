open Core_kernel
open Import

let domains (sys : _ Zexe_backend_common.Plonk_constraint_system.t) : Domains.t
    =
  let open Domain in
  let public_input_size = Set_once.get_exn sys.public_input_size [%here] in
  let rows = public_input_size + List.length sys.rows_rev in
  (* TODO: h should maybe be ceil_log2 (rows + public_input_size + 1) *)
  { h= Pow_2_roots_of_unity Int.(ceil_log2 rows)
  ; x= Pow_2_roots_of_unity (Int.ceil_log2 public_input_size) }

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
