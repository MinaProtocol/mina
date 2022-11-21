open Core_kernel
open Pickles_types
open Import
open Poly_types
open Hlist

(* Compute the domains corresponding to wrap_main *)
module Make
    (A : T0)
    (A_value : T0)
    (Ret_var : T0)
    (Ret_value : T0)
    (Auxiliary_var : T0)
    (Auxiliary_value : T0) =
struct
  module I =
    Inductive_rule.T (A) (A_value) (Ret_var) (Ret_value) (Auxiliary_var)
      (Auxiliary_value)

  let f_debug full_signature num_choices choices_length ~self ~choices
      ~max_proofs_verified =
    let num_choices = Hlist.Length.to_nat choices_length in
    let dummy_step_domains =
      Vector.init num_choices ~f:(fun _ -> Fix_domains.rough_domains)
    in
    let dummy_step_widths =
      Vector.init num_choices ~f:(fun _ ->
          Nat.to_int (Nat.Add.n max_proofs_verified) )
    in
    let dummy_step_keys =
      lazy
        (Vector.init num_choices ~f:(fun _ ->
             let g = Backend.Tock.Inner_curve.(to_affine_exn one) in
             Verification_key.dummy_commitments g ) )
    in
    Timer.clock __LOC__ ;
    let _, main =
      Wrap_main.wrap_main full_signature choices_length dummy_step_keys
        dummy_step_widths dummy_step_domains max_proofs_verified
    in
    Timer.clock __LOC__ ;
    let t =
      Fix_domains.domains
        (module Impls.Wrap.R1CS_constraint_system)
        (module Impls.Wrap)
        (Impls.Wrap.input ())
        (T (Snarky_backendless.Typ.unit (), Fn.id, Fn.id))
        main
    in
    Timer.clock __LOC__ ; t

  let f full_signature num_choices choices_length ~self ~choices
      ~max_proofs_verified =
    let res =
      Common.wrap_domains
        ~proofs_verified:(Nat.to_int (Nat.Add.n max_proofs_verified))
    in
    ( if debug then
      let res' =
        f_debug full_signature num_choices choices_length ~self ~choices
          ~max_proofs_verified
      in
      [%test_eq: Domains.t] res res' ) ;
    res
end
