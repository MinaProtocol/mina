open Core_kernel

let domains sys : Domains.t =
  let open Snarky_bn382_backend.R1cs_constraint_system in
  let open Domain in
  let weight = Weight.norm sys.weight in
  let witness_size = 1 + sys.public_input_size + sys.auxiliary_input_size in
  { h= Pow_2_roots_of_unity Int.(ceil_log2 (max sys.constraints witness_size))
  ; k= Pow_2_roots_of_unity (Int.ceil_log2 weight)
  ; x= Pow_2_roots_of_unity (Int.ceil_log2 (1 + sys.public_input_size)) }

let rough_domains : Domains.t =
  let d = Domain.Pow_2_roots_of_unity 17 in
  {h= d; k= d; x= Pow_2_roots_of_unity 6}

let domains (type field a b)
    (module Impl : Snarky.Snark_intf.Run
      with type field = field
       and type R1CS_constraint_system.t = ( a
                                           , b )
                                           Snarky_bn382_backend
                                           .R1cs_constraint_system
                                           .t) (Spec.ETyp.T (typ, conv)) main =
  let main x () : unit = main (conv x) in
  domains (Impl.constraint_system ~exposing:[typ] main)
