open Core
open Pickles_types
open Zexe_backend
open Tuple_lib
open Common
open Import

type t =
  (G1.Affine.t, G1.Affine.t Unshifted_acc.t) Pairing_marlin_types.Accumulator.t

module Projective = struct
  type t = (G1.t, G1.t Unshifted_acc.t) Pairing_marlin_types.Accumulator.t
end

let accumulate (prev_acc : t) (proof : Pairing_based.Proof.t) ~domain_h
    ~domain_k ~r ~r_k ~r_xi_sum ~beta_1 ~beta_2 ~beta_3 (f_1, f_2, f_3) : t =
  let open G1 in
  let prev_acc = Pairing_marlin_types.Accumulator.map ~f:of_affine prev_acc in
  let proof1, proof2, proof3 = Triple.map proof.openings.proofs ~f:of_affine in
  let conv = Double.map ~f:of_affine in
  let g1 = conv (fst proof.messages.gh_1) in
  let g2 = conv (fst (snd proof.messages.sigma_gh_2)) in
  let g3 = conv (fst (snd proof.messages.sigma_gh_3)) in
  Pairing_marlin_types.Accumulator.map ~f:to_affine_exn
    { degree_bound_checks=
        Dlog_main.accumulate_degree_bound_checks' ~domain_h ~domain_k
          prev_acc.degree_bound_checks ~add ~scale ~r_h:r ~r_k g1 g2 g3
    ; opening_check=
        Dlog_main.accumulate_opening_check ~add ~negate
          ~scale_generator:(scale one) ~endo:scale ~r ~r_xi_sum
          prev_acc.opening_check (f_1, beta_1, proof1) (f_2, beta_2, proof2)
          (f_3, beta_3, proof3) }

(* Making this dynamic was a bit complicated. *)
let permitted_domains =
  [ Domain.Pow_2_roots_of_unity 14
  ; Pow_2_roots_of_unity 16
  ; Pow_2_roots_of_unity 17
  ; Pow_2_roots_of_unity 18
  ; Pow_2_roots_of_unity 19 ]

let check_step_domains step_domains =
  Vector.iter step_domains ~f:(fun {Domains.h; k} ->
      List.iter [h; k] ~f:(fun d ->
          if not (List.mem permitted_domains d ~equal:Domain.equal) then
            failwithf "Bad domain size 2^%d" (Domain.log2_size d) () ) )

let permitted_shifts =
  List.map permitted_domains ~f:(fun d -> Domain.size d - 1) |> Int.Set.of_list

let typ =
  Pairing_marlin_types.Accumulator.typ permitted_shifts Dlog_main_inputs.G1.typ

let batch_check (ts : t list) =
  let permitted_shifts =
    Set.to_sequence ~order:`Increasing permitted_shifts |> Sequence.to_list
  in
  let d =
    let open Snarky_bn382.Usize_vector in
    let d = create () in
    List.iter permitted_shifts ~f:(fun x ->
        emplace_back d (Unsigned.Size_t.of_int x) ) ;
    d
  in
  let open G1.Affine.Vector in
  let s = create () in
  let u = create () in
  let t = create () in
  let p = create () in
  List.iter ts
    ~f:(fun { opening_check= {r_f_minus_r_v_plus_rz_pi; r_pi}
            ; degree_bound_checks= {shifted_accumulator; unshifted_accumulators}
            }
       ->
      let push v g = emplace_back v (G1.Affine.to_backend g) in
      (let us =
         Map.to_sequence ~order:`Increasing_key unshifted_accumulators
       in
       assert (
         [%eq: int list] permitted_shifts Sequence.(to_list (map us ~f:fst)) ) ;
       Sequence.iter us ~f:(fun (_, g) -> push u g)) ;
      push s shifted_accumulator ;
      push t r_f_minus_r_v_plus_rz_pi ;
      push p r_pi ) ;
  let res =
    Snarky_bn382.batch_pairing_check
      (* TODO: Don't load the whole thing! *)
      (Pairing_based.Keypair.load_urs ())
      d s u t p
  in
  Snarky_bn382.Usize_vector.delete d ;
  List.iter ~f:delete [s; u; t; p] ;
  res

let dummy : t Lazy.t =
  lazy
    (Common.time "dummy pairing acc" (fun () ->
         let opening_check : _ Pairing_marlin_types.Accumulator.Opening_check.t
             =
           (* TODO: Leaky *)
           let t =
             Snarky_bn382.Fp_urs.dummy_opening_check
               (Zexe_backend.Pairing_based.Keypair.load_urs ())
           in
           { r_f_minus_r_v_plus_rz_pi=
               Snarky_bn382.G1.Affine.Pair.f0 t
               |> Zexe_backend.G1.Affine.of_backend
           ; r_pi=
               Snarky_bn382.G1.Affine.Pair.f1 t
               |> Zexe_backend.G1.Affine.of_backend }
         in
         let degree_bound_checks :
             _ Pairing_marlin_types.Accumulator.Degree_bound_checks.t =
           let shifts = Int.Set.to_list permitted_shifts in
           (* TODO: Leaky *)
           let t =
             let v =
               let open Snarky_bn382.Usize_vector in
               let v = create () in
               List.iter shifts ~f:(fun i ->
                   emplace_back v (Unsigned.Size_t.of_int i) ) ;
               v
             in
             Snarky_bn382.Fp_urs.dummy_degree_bound_checks
               (Zexe_backend.Pairing_based.Keypair.load_urs ())
               v
           in
           { shifted_accumulator=
               Snarky_bn382.G1.Affine.Vector.get t 0
               |> Zexe_backend.G1.Affine.of_backend
           ; unshifted_accumulators=
               List.mapi shifts ~f:(fun i s ->
                   ( s
                   , Zexe_backend.G1.Affine.of_backend
                       (Snarky_bn382.G1.Affine.Vector.get t (1 + i)) ) )
               |> Int.Map.of_alist_exn }
         in
         {Pairing_marlin_types.Accumulator.opening_check; degree_bound_checks}
     ))
