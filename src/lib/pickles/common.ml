open Core_kernel
open Pickles_types
module Unshifted_acc =
  Pairing_marlin_types.Accumulator.Degree_bound_checks.Unshifted_accumulators
open Import
open Backend

module Max_degree = struct
  let step = 1 lsl Nat.to_int Backend.Tick.Rounds.n

  let wrap = 1 lsl Nat.to_int Backend.Tock.Rounds.n
end

let tick_shifts : Domain.t -> Backend.Tick.Field.t Tuple_lib.Double.t =
  Memo.general ~cache_size_bound:20 ~hashable:Domain.Table.hashable (function
      | Pow_2_roots_of_unity x -> failwithf "sample_shifts %d" x () )

let tock_shifts : Domain.t -> Backend.Tock.Field.t Tuple_lib.Double.t =
  Memo.general ~cache_size_bound:20 ~hashable:Domain.Table.hashable (function
      | Pow_2_roots_of_unity x -> failwithf "sample_shifts %d" x () )

let wrap_domains =
  { Domains.h= Pow_2_roots_of_unity 17
  ; x=
      Pow_2_roots_of_unity
        (let (T (typ, _)) = Impls.Wrap.input () in
         Int.ceil_log2 (1 + Impls.Wrap.Data_spec.size [typ])) }

let hash_pairing_me_only ~app_state
    (t : _ Types.Pairing_based.Proof_state.Me_only.t) =
  let g (x, y) = [x; y] in
  let open Backend in
  Tick_field_sponge.digest Tick_field_sponge.params
    (Types.Pairing_based.Proof_state.Me_only.to_field_elements t ~g
       ~comm:
         (fun (x :
                Tock.Curve.Affine.t
                Dlog_plonk_types.Poly_comm.Without_degree_bound.t) ->
         Array.concat_map x ~f:(Fn.compose Array.of_list g) )
       ~app_state)

let hash_dlog_me_only (type n) (max_branching : n Nat.t)
    (t :
      ( Tick.Curve.Affine.t
      , (_, n) Vector.t )
      Types.Dlog_based.Proof_state.Me_only.t) =
  Tock_field_sponge.digest Tock_field_sponge.params
    (Types.Dlog_based.Proof_state.Me_only.to_field_elements t
       ~g1:(fun ((x, y) : Tick.Curve.Affine.t) -> [x; y]))

let dlog_pcs_batch (type n_branching total)
    ((without_degree_bound, pi) :
      total Nat.t * (n_branching, Nat.N8.n, total) Nat.Adds.t) ~max_quot_size =
  Pcs_batch.create ~without_degree_bound ~with_degree_bound:[max_quot_size]

module Pairing_pcs_batch = struct
  let beta_1 : (int, _, _) Pcs_batch.t =
    Pcs_batch.create ~without_degree_bound:Nat.N6.n ~with_degree_bound:[]

  let beta_2 : (int, _, _) Pcs_batch.t =
    Pcs_batch.create ~without_degree_bound:Nat.N2.n ~with_degree_bound:[]

  let beta_3 : (int, _, _) Pcs_batch.t =
    Pcs_batch.create ~without_degree_bound:Nat.N14.n ~with_degree_bound:[]
end

let when_profiling profiling default =
  match
    Option.map (Sys.getenv_opt "PICKLES_PROFILING") ~f:String.lowercase
  with
  | None | Some ("0" | "false") ->
      default
  | Some _ ->
      profiling

let time lab f =
  when_profiling
    (fun () ->
      let start = Time.now () in
      let x = f () in
      let stop = Time.now () in
      printf "%s: %s\n%!" lab (Time.Span.to_string_hum (Time.diff stop start)) ;
      x )
    f ()

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ~length s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1) )
    |> fun a -> List.take a length

let bits_to_bytes bits =
  let byte_of_bits bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
        if b then acc lor (1 lsl i) else acc )
    |> Char.of_int_exn
  in
  List.map (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)) ~f:byte_of_bits
  |> String.of_char_list

let group_map m ~a ~b =
  let params = Group_map.Params.create m {a; b} in
  stage (fun x -> Group_map.to_group m ~params x)

(* The group of units F^× decomposes as

   F^× = < g > ⊕ H

   where g ([two_adic_root_of_unity] below) has order 2^two_adicity.
*)
let det_sqrt (type f) ((module Impl) : f Snarky_backendless.Snark.m)
    ~(two_adic_root_of_unity : f) ~two_adicity ~(det_sqrt : f -> f)
    ~(det_sqrt_witness :
       f -> f Zexe_backend_common.Field.Det_sqrt_witness.t option) =
  let open Impl in
  (* This maps n (as a bitstring) to g^n *)
  let _inj =
    (* "double and add" *)
    let rec go acc bits =
      match bits with
      | [] ->
          acc
      | b :: bits ->
          let acc = Field.square acc in
          let acc =
            Field.if_ b
              ~then_:(Field.scale acc two_adic_root_of_unity)
              ~else_:acc
          in
          go acc bits
    in
    fun bits -> go Field.one (List.rev bits)
  in
  (* This projects onto the H subgroup by the map
     x -> x^|< g >|
  *)
  let _project_h =
    (* Compute x^(2^i) *)
    let rec pow2_pow x i =
      if i = 0 then x (* x^(2^0) = x^1 = x *)
      else
        (* (x^2)^(2^(i - 1)) = x^(2 * 2^(i - 1)) = x^(2^i) *)
        pow2_pow (Field.square x) (i - 1)
    in
    fun x -> pow2_pow x two_adicity
  in
  stage (fun t ->
      let _n = two_adicity - 1 in
      (* t has two square roots, y and -y.

         Consider how they appear in < g > ⊕ H.

         Note that -1 = g^(2^(two_adicity - 1)) since g^(2^(two_adicity - 1)) != 1 and g^(2^(two_adicity - 1))^2 = 1.

         Say y = g^k h.

         Then
         -y
         = g^(2^(two_adicity - 1)) g^n h
         = g^(2^n + k) h

         What we can conclude from this is one of the square roots of t has the top bit = 1, and the other = 0,
         and their bit representations, and h representations are otherwise the same.

         So, the h components and lower bits are unique, and the top bit may be 1 or 0.

         As a deterministic square root, we choose the one with top bit = 0.
      *)
      (* TODO: Turn back on for mainnet if it's not eliminated by the improved
         IPA by then. *)
      (*
      let c, d =
        exists
          Typ.(field * list ~length:n Boolean.typ)
          ~compute:
            As_prover.(
              fun () ->
                let r = Option.value_exn (det_sqrt_witness (read_var t)) in
                let bits =
                  List.init n ~f:(fun i ->
                      Unsigned.UInt64.(
                        equal one (logand (shift_right r.d i) one)) )
                in
                (r.c, bits))
      in 
      let res = Field.mul (project_h c) (inj d) in
      *)
      let res =
        exists Field.typ ~compute:As_prover.(fun () -> det_sqrt (read_var t))
      in
      assert_square res t ; res )

module Shifts = struct
  let tock : Tock.Field.t Shifted_value.Shift.t =
    Shifted_value.Shift.create (module Tock.Field)

  let tick : Tick.Field.t Shifted_value.Shift.t =
    Shifted_value.Shift.create (module Tick.Field)
end

module Ipa = struct
  open Backend

  (* TODO: Make all this completely generic over backend *)

  let compute_challenge (type f) ~endo_to_field
      (module Field : Zexe_backend.Field.S with type t = f) ~is_square c =
    let x = endo_to_field c in
    let nonresidue = Field.of_int 5 in
    (* TODO: Don't actually need to transmit the "is_square" bit on the wire *)
    [%test_eq: bool] is_square (Field.is_square x) ;
    Field.det_sqrt (if is_square then x else Field.(nonresidue * x))

  let compute_challenges ~endo_to_field field chals =
    Vector.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
        compute_challenge field ~is_square ~endo_to_field prechallenge )

  module Wrap = struct
    let field =
      (module Tock.Field : Zexe_backend.Field.S with type t = Tock.Field.t)

    let endo_to_field = Endo.Dee.to_field

    let compute_challenge c = compute_challenge field ~endo_to_field c

    let compute_challenges cs = compute_challenges field ~endo_to_field cs

    let compute_sg chals =
      let open Snarky_bn382.Tweedle.Dee.Field_poly_comm in
      let comm =
        Snarky_bn382.Tweedle.Dee.Field_urs.b_poly_commitment
          (Backend.Tock.Keypair.load_urs ())
          (Backend.Tock.Field.Vector.of_array
             (Pickles_types.Vector.to_array (compute_challenges chals)))
      in
      Backend.Tock.Curve.Affine.Backend.Vector.get (unshifted comm) 0
      |> Backend.Tock.Curve.Affine.of_backend |> Or_infinity.finite_exn
  end

  module Step = struct
    let field =
      (module Tick.Field : Zexe_backend.Field.S with type t = Tick.Field.t)

    let endo_to_field = Endo.Dum.to_field

    let compute_challenge c = compute_challenge field ~endo_to_field c

    let compute_challenges cs = compute_challenges field ~endo_to_field cs

    let compute_sg chals =
      let open Snarky_bn382.Tweedle.Dum.Field_poly_comm in
      let comm =
        Snarky_bn382.Tweedle.Dum.Field_urs.b_poly_commitment
          (Backend.Tick.Keypair.load_urs ())
          (Backend.Tick.Field.Vector.of_array
             (Pickles_types.Vector.to_array (compute_challenges chals)))
      in
      Backend.Tick.Curve.Affine.Backend.Vector.get (unshifted comm) 0
      |> Backend.Tick.Curve.Affine.of_backend |> Or_infinity.finite_exn

    let accumulator_check comm_chals =
      let open Snarky_bn382.Tweedle.Dum.Plonk.Field_poly_comm in
      let chals =
        let open Backend.Tick.Field.Vector in
        let v = create () in
        List.iter comm_chals ~f:(fun (_, chals) ->
            Pickles_types.Vector.iter chals ~f:(emplace_back v) ) ;
        v
      in
      let comms =
        let open Backend.Tick.Curve.Affine in
        let open Backend.Vector in
        let v = create () in
        List.iter comm_chals ~f:(fun (comm, _) ->
            emplace_back v (to_backend (Finite comm)) ) ;
        v
      in
      Snarky_bn382.Tweedle.Dum.Plonk.Field_urs.batch_accumulator_check
        (Backend.Tick.Keypair.load_urs ())
        comms chals
  end
end

let tock_unpadded_public_input_of_statement prev_statement =
  let open Zexe_backend in
  let input =
    let (T (typ, _conv)) = Impls.Wrap.input () in
    Impls.Wrap.generate_public_input [typ] prev_statement
  in
  List.init
    (Backend.Tock.Field.Vector.length input)
    ~f:(Backend.Tock.Field.Vector.get input)

let tock_public_input_of_statement s =
  let open Zexe_backend in
  tock_unpadded_public_input_of_statement s

let tick_public_input_of_statement ~max_branching
    (prev_statement : _ Types.Pairing_based.Statement.t) =
  let open Zexe_backend in
  let input =
    let (T (input, conv)) =
      Impls.Step.input ~branching:max_branching ~wrap_rounds:Tock.Rounds.n
    in
    Impls.Step.generate_public_input [input] prev_statement
  in
  List.init
    (Backend.Tick.Field.Vector.length input)
    ~f:(Backend.Tick.Field.Vector.get input)

let index_commitment_length k ~max_degree =
  let actual =
    Int.round_up ~to_multiple_of:max_degree (Domain.size k) / max_degree
  in
  [%test_eq: int] actual 1 ;
  1

let max_log2_degree = Pickles_base.Side_loaded_verification_key.max_log2_degree
