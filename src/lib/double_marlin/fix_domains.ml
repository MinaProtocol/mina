
open Core_kernel

let domains sys =
  let open Snarky_bn382_backend.R1cs_constraint_system in
  let open Domain in
  let weight = Weight.norm sys.weight in
  let witness_size =
    1 + sys.public_input_size + sys.auxiliary_input_size
  in
  let h =
    Pow_2_roots_of_unity
      Int.(ceil_log2 (max sys.constraints witness_size))
  in
  let k = Pow_2_roots_of_unity (Int.ceil_log2 weight) in
  (h, k)

let rough_domains =
  Domain.(Pow_2_roots_of_unity 17, Pow_2_roots_of_unity 17)

let domains  (type field) (type a)
    (module Impl : Snarky.Snark_intf.Run 
      with type field = field
       and type R1CS_constraint_system.t = a Snarky_bn382_backend.R1cs_constraint_system.t
    )
    (Spec.ETyp.T (typ, conv)) main
  =
  let main x () : unit =
    main (conv x)
  in
  domains (Impl.constraint_system ~exposing:[typ] main)
