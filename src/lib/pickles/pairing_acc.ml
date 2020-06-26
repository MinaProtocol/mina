open Core
open Pickles_types
open Zexe_backend
open Tuple_lib
open Common
open Import
module Accumulator = Pairing_marlin_types.Accumulator

(* This implements essentially what is described in section 8.1 (currently page 42) of
   https://eprint.iacr.org/2020/499.pdf, although this was implemented a few months
   before that paper existed. *)

let accumulate_degree_bound_checks' ~update_unshifted ~add ~scale ~r_h ~r_k
    { Accumulator.Degree_bound_checks.shifted_accumulator
    ; unshifted_accumulators } (g1, g1_s) (g2, g2_s) (g3, g3_s) =
  let ( + ) = add in
  let ( * ) = Fn.flip scale in
  let shifted_accumulator =
    shifted_accumulator + (r_h * (g1 + (r_h * g2))) + (r_k * g3)
  in
  let h_update = r_h * (g1_s + (r_h * g2_s)) in
  let k_update = r_k * g3_s in
  let unshifted_accumulators =
    update_unshifted unshifted_accumulators (h_update, k_update)
  in
  {Accumulator.Degree_bound_checks.shifted_accumulator; unshifted_accumulators}

type t =
  (G1.Affine.t, G1.Affine.t Unshifted_acc.t) Pairing_marlin_types.Accumulator.t

module Projective = struct
  type t = (G1.t, G1.t Unshifted_acc.t) Pairing_marlin_types.Accumulator.t
end

let accumulate_degree_bound_checks ~domain_h ~domain_k ~add =
  accumulate_degree_bound_checks' ~add
    ~update_unshifted:(fun unsh (h_update, k_update) ->
      Map.update unsh
        (Domain.size domain_h - 1)
        ~f:(fun x -> add h_update (Option.value_exn x))
      |> Fn.flip Map.update
           (Domain.size domain_k - 1)
           ~f:(fun x -> add k_update (Option.value_exn x)) )

(*
   check that pi proves that U opens to v at z.

   pi =? commitmennt to (U - v * g ) / (beta*g - z)

   e(pi, beta*g - z*g) = e(U - v, g)

   e(pi, beta*g) - e(z*pi, g) - e(U - v, g) = 0
   e(pi, beta*g) - e(z*pi - (U - v * g), g) = 0

   sum_i r^i e(pi_i, beta_i*g) - e(z*pi - (U - v_i * g), g) = 0
*)

let accumulate_opening_check ~add ~negate ~endo ~scale_generator ~r
    ~(* r should be exposed. *) r_xi_sum (* s should be exposed *)
    {Accumulator.Opening_check.r_f_minus_r_v_plus_rz_pi; r_pi}
    (f_1, beta_1, pi_1) (f_2, beta_2, pi_2) (f_3, beta_3, pi_3) =
  let ( + ) = add in
  let ( * ) s p = endo p s in
  let r_f_minus_r_v_plus_rz_pi =
    let rz_pi_term =
      let zpi_1 = beta_1 * pi_1 in
      let zpi_2 = beta_2 * pi_2 in
      let zpi_3 = beta_3 * pi_3 in
      r * (zpi_1 + (r * (zpi_2 + (r * zpi_3))))
      (* Could be more efficient at the cost of more public inputs. *)
      (* sum_{i=1}^3 r^i beta_i pi_i *)
    in
    let f_term = r * (f_1 + (r * (f_2 + (r * f_3)))) in
    let v_term = scale_generator r_xi_sum in
    r_f_minus_r_v_plus_rz_pi + f_term + negate v_term + rz_pi_term
  in
  let pi_term =
    (* sum_{i=1}^3 r^i pi_i *)
    r * (pi_1 + (r * (pi_2 + (r * pi_3))))
  in
  {Accumulator.Opening_check.r_f_minus_r_v_plus_rz_pi; r_pi= r_pi + pi_term}

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
        accumulate_degree_bound_checks ~domain_h ~domain_k
          prev_acc.degree_bound_checks ~add ~scale ~r_h:r ~r_k g1 g2 g3
    ; opening_check=
        accumulate_opening_check ~add ~negate ~scale_generator:(scale one)
          ~endo:scale ~r ~r_xi_sum prev_acc.opening_check (f_1, beta_1, proof1)
          (f_2, beta_2, proof2) (f_3, beta_3, proof3) }

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

module Checked = struct
  open Dlog_main_inputs
  open Impl

  let accumulate_degree_bound_checks ~step_domains:(step_h, step_k) =
    let mask_gs bs gs =
      let open Field in
      List.map2_exn bs gs ~f:(fun (b : Boolean.var) (x, y) ->
          let b = (b :> t) in
          (b * x, b * y) )
      |> List.reduce_exn ~f:(fun (x1, y1) (x2, y2) -> (x1 + x2, y1 + y2))
    in
    accumulate_degree_bound_checks' ~add:G1.( + )
      ~update_unshifted:(fun m (uh, uk) ->
        let m = Map.to_sequence ~order:`Increasing_key m |> Sequence.to_list in
        let keys = List.map m ~f:fst in
        let add domain delta elts =
          let flags =
            let domain_size = domain#size in
            List.map keys ~f:(fun shift ->
                Field.(equal (domain_size - one) (of_int shift)) )
          in
          let elt_plus_delta = G1.( + ) (mask_gs flags elts) delta in
          List.map2_exn flags elts ~f:(fun b g ->
              G1.if_ b ~then_:elt_plus_delta ~else_:g )
        in
        add step_h uh (List.map m ~f:snd)
        |> add step_k uk |> List.zip_exn keys |> Int.Map.of_alist_exn )

  let combine_pairing_accs : type n. (_, n) Vector.t -> _ = function
    | [] ->
        failwith "combine_pairing_accs: empty list"
    | [acc] ->
        acc
    | a :: accs ->
        let open Pairing_marlin_types.Accumulator in
        let (module Shifted) = G1.shifted () in
        Vector.fold accs
          ~init:(map a ~f:(fun x -> Shifted.(add zero x)))
          ~f:(fun acc t -> map2 acc t ~f:Shifted.add)
        |> map ~f:Shifted.unshift_nonzero
end

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
