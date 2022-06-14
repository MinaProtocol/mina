open Core_kernel
open Pickles_types
open Import
open Poly_types
open Hlist

(* Compute the domains corresponding to wrap_main *)
module Make (A : T0) (A_value : T0) = struct
  module I = Inductive_rule.T (A) (A_value)

  let prev (type a1 a2 a3 a4 ws hs) ~self
      ~(choices : (a1, a2, a3, a4, ws, hs) H6.T(I).t) =
    let module M_inner =
      H6.Map (Tag) (E06 (Domains))
        (struct
          let f :
              type a1 a2 a3 a4 a5 a6.
              (a1, a2, a3, a4, a5, a6) Tag.t -> Domains.t =
           fun t ->
            Types_map.lookup_map t ~self:self.Tag.id
              ~default:(fun () -> assert false)
              ~f:(function
                | `Side_loaded d ->
                    fun () ->
                      Common.wrap_domains
                        ~proofs_verified:
                          (Nat.to_int
                             (Nat.Add.n d.permanent.max_proofs_verified) )
                | `Compiled d ->
                    fun () -> d.wrap_domains )
              ()
        end)
    in
    let module M =
      H6.Map (I) (H6.T (E06 (Domains)))
        (struct
          let f :
              type vars values ret_vars ret_values env widths heights.
                 (vars, values, ret_vars, ret_values, widths, heights) I.t
              -> ( vars
                 , values
                 , ret_vars
                 , ret_values
                 , widths
                 , heights )
                 H6.T(E06(Domains)).t =
           fun rule -> M_inner.f rule.prevs
        end)
    in
    M.f choices

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
    let prev_domains = prev ~self ~choices in
    Timer.clock __LOC__ ;
    let _, main =
      Wrap_main.wrap_main full_signature choices_length dummy_step_keys
        dummy_step_widths dummy_step_domains prev_domains max_proofs_verified
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
