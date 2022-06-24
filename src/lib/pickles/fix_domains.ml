open Core_kernel
open Import

let zk_rows = 3

let domains (sys : _ Kimchi_backend_common.Plonk_constraint_system.t) :
    Domains.t =
  let open Domain in
  let public_input_size = Set_once.get_exn sys.public_input_size [%here] in
  let rows = zk_rows + public_input_size + List.length sys.rows_rev in
  { h = Pow_2_roots_of_unity Int.(ceil_log2 rows) }

let rough_domains : Domains.t =
  let d = Domain.Pow_2_roots_of_unity 20 in
  { h = d }

let domains (type field rust_gates)
    (module Impl : Snarky_backendless.Snark_intf.Run
      with type field = field
       and type R1CS_constraint_system.t =
         (field, rust_gates) Kimchi_backend_common.Plonk_constraint_system.t )
    (Spec.ETyp.T (typ, conv, _conv_inv))
    (Spec.ETyp.T (return_typ, _ret_conv, ret_conv_inv)) main =
  let main x () = ret_conv_inv (main (conv x)) in
  domains (Impl.constraint_system ~exposing:[ typ ] ~return_typ main)
