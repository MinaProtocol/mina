open Core_kernel
open Pickles_types
open Import
open Poly_types

(* Compute the domains corresponding to wrap_main *)

(* TODO: this functor does not depend on any of its argument why? *)

module Make
    (A : T0)
    (A_value : T0)
    (Ret_var : T0)
    (Ret_value : T0)
    (Auxiliary_var : T0)
    (Auxiliary_value : T0) =
struct
  let f_debug full_signature _num_choices choices_length ~num_step_chunks
      ~num_wrap_chunks ~feature_flags ~max_proofs_verified =
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
             Verification_key.dummy_commitments [| g |] ) )
    in
    Timer.clock __LOC__ ;
    let srs = Backend.Tick.Keypair.load_urs () in
    let _, main =
      Wrap_main.wrap_main ~num_step_chunks ~num_wrap_chunks ~feature_flags ~srs
        full_signature choices_length dummy_step_keys dummy_step_widths
        dummy_step_domains max_proofs_verified
    in
    Timer.clock __LOC__ ;
    let t =
      Fix_domains.domains
        (module Impls.Wrap)
        (Impls.Wrap.input ())
        (T (Snarky_backendless.Typ.unit (), Fn.id, Fn.id))
        main
    in
    Timer.clock __LOC__ ; t

  let f full_signature num_choices choices_length ~num_step_chunks
      ~num_wrap_chunks ~feature_flags ~max_proofs_verified =
    let res =
      Common.wrap_domains
        ~proofs_verified:(Nat.to_int (Nat.Add.n max_proofs_verified))
    in
    ( if debug then
      let res' =
        f_debug full_signature num_choices choices_length ~num_step_chunks
          ~num_wrap_chunks ~feature_flags ~max_proofs_verified
      in
      [%test_eq: Domains.t] res res' ) ;
    res
end
[@@warning "-60"]
