open Core_kernel
open Pickles_types
module G = Zexe_backend.G
module Rounds = Zexe_backend.Dlog_based.Rounds
module Unshifted_acc =
  Pairing_marlin_types.Accumulator.Degree_bound_checks.Unshifted_accumulators
open Import

let crs_max_degree = 1 lsl Nat.to_int Rounds.n

let wrap_domains =
  { Domains.h= Pow_2_roots_of_unity 18
  ; k= Pow_2_roots_of_unity 18
  ; x= Pow_2_roots_of_unity 0 }

let hash_pairing_me_only ~app_state
    (t :
      ( G.Affine.t
      , 's
      , (G.Affine.t, _) Vector.t )
      Types.Pairing_based.Proof_state.Me_only.t) =
  let g (x, y) = [x; y] in
  Fp_sponge.digest Fp_sponge.params
    (Types.Pairing_based.Proof_state.Me_only.to_field_elements t ~g
       ~comm:
         (fun (x :
                G.Affine.t Dlog_marlin_types.Poly_comm.Without_degree_bound.t) ->
         List.concat_map (Array.to_list x) ~f:g )
       ~app_state)
  |> Digest.Constant.of_bits

let hash_dlog_me_only t =
  Fq_sponge.digest Fq_sponge.params
    (Types.Dlog_based.Proof_state.Me_only.to_field_elements t
       ~g1:(fun ((x, y) : Zexe_backend.G1.Affine.t) -> [x; y]))
  |> Digest.Constant.of_bits

let dlog_pcs_batch (type n_branching total)
    ((without_degree_bound, pi) :
      total Nat.t * (n_branching, Nat.N19.n, total) Nat.Adds.t) ~h_minus_1
    ~k_minus_1 =
  Pcs_batch.create ~without_degree_bound
    ~with_degree_bound:[h_minus_1; h_minus_1; k_minus_1]

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

let compute_challenge ~is_square x =
  let open Zexe_backend in
  let nonresidue = Fq.of_int 7 in
  let x = Endo.Dlog.to_field x in
  assert (is_square = Fq.is_square x) ;
  Fq.sqrt (if is_square then x else Fq.(nonresidue * x))

let compute_challenges chals =
  Vector.map chals ~f:(fun {Bulletproof_challenge.prechallenge; is_square} ->
      compute_challenge ~is_square prechallenge )

let compute_sg chals =
  let open Zexe_backend in
  let open Snarky_bn382.Fq_poly_comm in
  let comm =
    Snarky_bn382.Fq_urs.b_poly_commitment
      (Dlog_based.Keypair.load_urs ())
      (Fq.Vector.of_array (Vector.to_array (compute_challenges chals)))
  in
  Snarky_bn382.G.Affine.Vector.get (unshifted comm) 0 |> G.Affine.of_backend

let fq_unpadded_public_input_of_statement prev_statement =
  let open Zexe_backend in
  let input =
    let (T (typ, _conv)) = Impls.Dlog_based.input () in
    Impls.Dlog_based.generate_public_input [typ] prev_statement
  in
  List.init (Fq.Vector.length input) ~f:(Fq.Vector.get input)

let fq_public_input_of_statement s =
  let open Zexe_backend in
  Fq.one :: fq_unpadded_public_input_of_statement s

let fp_public_input_of_statement ~max_branching
    (prev_statement : _ Types.Pairing_based.Statement.t) =
  let open Zexe_backend in
  let input =
    let (T (input, conv)) =
      Impls.Pairing_based.input ~branching:max_branching
        ~bulletproof_log2:Rounds.n
    in
    Impls.Pairing_based.generate_public_input [input] prev_statement
  in
  Fp.one :: List.init (Fp.Vector.length input) ~f:(Fp.Vector.get input)
