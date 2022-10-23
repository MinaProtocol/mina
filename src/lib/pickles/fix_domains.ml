open Core_kernel
open Import

let zk_rows = 3

let rough_domains : Domains.t =
  let d = Domain.Pow_2_roots_of_unity 20 in
  { h = d }

let domains (type field cs)
    (module CS : Kimchi_pasta_constraint_system.Intf.With_accessors
      with type t = cs )
    (module Impl : Snarky_backendless.Snark_intf.Run
      with type field = field
       and type constraint_system = cs ) (Spec.ETyp.T (typ, conv, _conv_inv))
    (Spec.ETyp.T (return_typ, _ret_conv, ret_conv_inv)) main =
  let main x () = ret_conv_inv (main (conv x)) in

  let domains2 sys : Domains.t =
    let open Domain in
    let public_input_size = CS.get_primary_input_size sys in
    let rows = zk_rows + public_input_size + CS.get_rows_len sys in
    { h = Pow_2_roots_of_unity Int.(ceil_log2 rows) }
  in
  domains2 (Impl.constraint_system ~input_typ:typ ~return_typ main)
