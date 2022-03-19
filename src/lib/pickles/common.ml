open Core_kernel
open Pickles_types
open Import
open Backend

module Max_degree = struct
  let step_log2 = Nat.to_int Backend.Tick.Rounds.n

  let step = 1 lsl step_log2

  let wrap_log2 = Nat.to_int Backend.Tock.Rounds.n

  let wrap = 1 lsl wrap_log2
end

let tick_shifts, tock_shifts =
  let mk g =
    let f =
      Memo.general ~cache_size_bound:20 ~hashable:Int.hashable (fun log2_size ->
          g log2_size)
    in
    fun ~log2_size -> f log2_size
  in
  ( mk Kimchi.Protocol.VerifierIndex.Fp.shifts
  , mk Kimchi.Protocol.VerifierIndex.Fq.shifts )

let wrap_domains =
  { Domains.h = Pow_2_roots_of_unity 15
  ; x =
      Pow_2_roots_of_unity
        (let (T (typ, _)) = Impls.Wrap.input () in
         Int.ceil_log2 (Impls.Wrap.Data_spec.size [ typ ]))
  }

let hash_pairing_me_only ~app_state
    (t : _ Types.Pairing_based.Proof_state.Me_only.t) =
  let g (x, y) = [ x; y ] in
  let open Backend in
  Tick_field_sponge.digest Tick_field_sponge.params
    (Types.Pairing_based.Proof_state.Me_only.to_field_elements t ~g
       ~comm:(fun (x : Tock.Curve.Affine.t) -> Array.of_list (g x))
       ~app_state)

let hash_dlog_me_only (type n) (_max_branching : n Nat.t)
    (t :
      ( Tick.Curve.Affine.t
      , (_, n) Vector.t )
      Types.Dlog_based.Proof_state.Me_only.t) =
  Tock_field_sponge.digest Tock_field_sponge.params
    (Types.Dlog_based.Proof_state.Me_only.to_field_elements t
       ~g1:(fun ((x, y) : Tick.Curve.Affine.t) -> [ x; y ]))

let dlog_pcs_batch (type n_branching total)
    ((without_degree_bound, _pi) :
      total Nat.t * (n_branching, Nat.N26.n, total) Nat.Adds.t) =
  Pcs_batch.create ~without_degree_bound ~with_degree_bound:[]

let when_profiling profiling default =
  match Option.map (Sys.getenv_opt "PICKLES_PROFILING") ~f:String.lowercase with
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
      x)
    f ()

let bits_random_oracle =
  let h = Digestif.blake2s 32 in
  fun ~length s ->
    Digestif.digest_string h s |> Digestif.to_raw_string h |> String.to_list
    |> List.concat_map ~f:(fun c ->
           let c = Char.to_int c in
           List.init 8 ~f:(fun i -> (c lsr i) land 1 = 1))
    |> fun a -> List.take a length

let bits_to_bytes bits =
  let byte_of_bits bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
        if b then acc lor (1 lsl i) else acc)
    |> Char.of_int_exn
  in
  List.map (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)) ~f:byte_of_bits
  |> String.of_char_list

let group_map m ~a ~b =
  let params = Group_map.Params.create m { a; b } in
  stage (fun x -> Group_map.to_group m ~params x)

module Shifts = struct
  let tock1 : Tock.Field.t Shifted_value.Type1.Shift.t =
    Shifted_value.Type1.Shift.create (module Tock.Field)

  let tock2 : Tock.Field.t Shifted_value.Type2.Shift.t =
    Shifted_value.Type2.Shift.create (module Tock.Field)

  let tick1 : Tick.Field.t Shifted_value.Type1.Shift.t =
    Shifted_value.Type1.Shift.create (module Tick.Field)

  let tick2 : Tick.Field.t Shifted_value.Type2.Shift.t =
    Shifted_value.Type2.Shift.create (module Tick.Field)
end

let finite_exn : 'a Kimchi.Foundations.or_infinity -> 'a * 'a = function
  | Finite (x, y) ->
      (x, y)
  | Infinity ->
      failwith "finite_exn"

let or_infinite_conv :
    ('a * 'a) Or_infinity.t -> 'a Kimchi.Foundations.or_infinity = function
  | Finite (x, y) ->
      Finite (x, y)
  | Infinity ->
      Infinity

module Ipa = struct
  open Backend

  (* TODO: Make all this completely generic over backend *)

  let compute_challenge (type f) ~endo_to_field
      (module Field : Kimchi_backend.Field.S with type t = f) c =
    endo_to_field c

  let compute_challenges ~endo_to_field field chals =
    Vector.map chals ~f:(fun { Bulletproof_challenge.prechallenge } ->
        compute_challenge field ~endo_to_field prechallenge)

  module Wrap = struct
    let field =
      (module Tock.Field : Kimchi_backend.Field.S with type t = Tock.Field.t)

    let endo_to_field = Endo.Step_inner_curve.to_field

    let compute_challenge c = compute_challenge field ~endo_to_field c

    let compute_challenges cs = compute_challenges field ~endo_to_field cs

    let compute_sg chals =
      let comm =
        Kimchi.Protocol.SRS.Fq.b_poly_commitment
          (Backend.Tock.Keypair.load_urs ())
          (Pickles_types.Vector.to_array (compute_challenges chals))
      in
      comm.unshifted.(0) |> finite_exn
  end

  module Step = struct
    let field =
      (module Tick.Field : Kimchi_backend.Field.S with type t = Tick.Field.t)

    let endo_to_field = Endo.Wrap_inner_curve.to_field

    let compute_challenge c = compute_challenge field ~endo_to_field c

    let compute_challenges cs = compute_challenges field ~endo_to_field cs

    let compute_sg chals =
      let comm =
        Kimchi.Protocol.SRS.Fp.b_poly_commitment
          (Backend.Tick.Keypair.load_urs ())
          (Pickles_types.Vector.to_array (compute_challenges chals))
      in
      comm.unshifted.(0) |> finite_exn

    let accumulator_check comm_chals =
      let chals =
        Array.concat
        @@ List.map comm_chals ~f:(fun (_, chals) -> Vector.to_array chals)
      in
      let comms =
        Array.of_list_map comm_chals ~f:(fun (comm, _) ->
            Or_infinity.Finite comm)
      in
      let urs = Backend.Tick.Keypair.load_urs () in
      Promise.run_in_thread (fun () ->
          Kimchi.Protocol.SRS.Fp.batch_accumulator_check urs
            (Array.map comms ~f:or_infinite_conv)
            chals)
  end
end

let tock_unpadded_public_input_of_statement prev_statement =
  let input =
    let (T (typ, _conv)) = Impls.Wrap.input () in
    Impls.Wrap.generate_public_input [ typ ] prev_statement
  in
  List.init
    (Backend.Tock.Field.Vector.length input)
    ~f:(Backend.Tock.Field.Vector.get input)

let tock_public_input_of_statement s = tock_unpadded_public_input_of_statement s

let tick_public_input_of_statement ~max_branching
    (prev_statement : _ Types.Pairing_based.Statement.t) =
  let input =
    let (T (input, _conv)) =
      Impls.Step.input ~branching:max_branching ~wrap_rounds:Tock.Rounds.n
    in
    Impls.Step.generate_public_input [ input ] prev_statement
  in
  List.init
    (Backend.Tick.Field.Vector.length input)
    ~f:(Backend.Tick.Field.Vector.get input)

let max_log2_degree = Pickles_base.Side_loaded_verification_key.max_log2_degree

let max_quot_size ~of_int ~mul:( * ) ~sub:( - ) domain_size =
  of_int 5 * (domain_size - of_int 1)

let max_quot_size_int = max_quot_size ~of_int:Fn.id ~mul:( * ) ~sub:( - )

let ft_comm ~add:( + ) ~scale ~endoscale ~negate
    ~verification_key:(m : _ Plonk_verification_key_evals.t) ~alpha
    ~(plonk : _ Types.Dlog_based.Proof_state.Deferred_values.Plonk.In_circuit.t)
    ~t_comm =
  let ( * ) x g = scale g x in
  let _, [ sigma_comm_last ] =
    Vector.split m.sigma_comm
      (snd (Dlog_plonk_types.Permuts_minus_1.add Nat.N1.n))
  in
  let f_comm =
    (* The poseidon and generic gates are special cases,
       as they use coefficient commitments from the verifier index.
       Note that for all gates, powers of alpha start at a^0 = 1.
    *)
    let poseidon =
      let (pn :: ps) = Vector.rev m.coefficients_comm in
      let res =
        Vector.fold ~init:pn ps ~f:(fun acc c -> c + endoscale acc alpha)
      in
      scale res plonk.poseidon_selector |> negate
    in

    (*
    Remember, the layout of the generic gate:
    | 0  |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 |
    | l1 | r1 | o1 | m1 | c1 | l2 | r2 | o2 | m2 | c2 |
    *)
    let generic =
      let coeffs = Vector.to_array m.coefficients_comm in
      let (generic_selector
          :: l1 :: r1 :: o1 :: m1 :: l2 :: r2 :: o2 :: m2 :: _) =
        plonk.generic
      in
      (* Second gate first, to multiply with a power of alpha. *)
      let snd_gate = l2 * coeffs.(5) in
      let snd_gate = snd_gate + (r2 * coeffs.(6)) in
      let snd_gate = snd_gate + (o2 * coeffs.(7)) in
      let snd_gate = snd_gate + (m2 * coeffs.(8)) in
      let snd_gate = snd_gate + coeffs.(9) in
      let snd_gate = endoscale snd_gate alpha in
      (* And then the first gate. *)
      let generic_gate = snd_gate + (l1 * coeffs.(0)) in
      let generic_gate = generic_gate + (r1 * coeffs.(1)) in
      let generic_gate = generic_gate + (o1 * coeffs.(2)) in
      let generic_gate = generic_gate + (m1 * coeffs.(3)) in
      let generic_gate = generic_gate + coeffs.(4) in
      (* generic_selector * (fst_gate + snd_gate * alpha) *)
      generic_selector * generic_gate
    in

    List.reduce_exn ~f:( + )
      [ plonk.perm * sigma_comm_last
      ; generic
      ; poseidon
      ; plonk.vbmul * m.mul_comm
      ; plonk.complete_add * m.complete_add_comm
      ; plonk.endomul * m.emul_comm
      ; plonk.endomul_scalar * m.endomul_scalar_comm
      ]
  in
  let chunked_t_comm =
    let n = Array.length t_comm in
    let res = ref t_comm.(n - 1) in
    for i = n - 2 downto 0 do
      res := t_comm.(i) + scale !res plonk.zeta_to_srs_length
    done ;
    !res
  in
  f_comm + chunked_t_comm
  + negate (scale chunked_t_comm plonk.zeta_to_domain_size)
