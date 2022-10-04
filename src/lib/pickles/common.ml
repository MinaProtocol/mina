open Core_kernel
open Import
module Nat = Pickles_types.Nat
module Shifted_value = Pickles_types.Shifted_value
module Vector = Pickles_types.Vector

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
          g log2_size )
    in
    fun ~log2_size -> f log2_size
  in
  ( mk Kimchi_bindings.Protocol.VerifierIndex.Fp.shifts
  , mk Kimchi_bindings.Protocol.VerifierIndex.Fq.shifts )

let wrap_domains ~proofs_verified =
  let h =
    match proofs_verified with 0 -> 13 | 1 -> 14 | 2 -> 15 | _ -> assert false
  in
  { Domains.h = Pow_2_roots_of_unity h }

let hash_messages_for_next_step_proof ~app_state
    (t : _ Types.Step.Proof_state.Messages_for_next_step_proof.t) =
  let g (x, y) = [ x; y ] in
  let open Backend in
  Tick_field_sponge.digest Tick_field_sponge.params
    (Types.Step.Proof_state.Messages_for_next_step_proof.to_field_elements t ~g
       ~comm:(fun (x : Backend.Tock.Curve.Affine.t) -> Array.of_list (g x))
       ~app_state )

let dlog_pcs_batch (type proofs_verified total)
    ((without_degree_bound, _pi) :
      total Nat.t * (proofs_verified, Nat.N26.n, total) Nat.Adds.t ) =
  Pickles_types.Pcs_batch.create ~without_degree_bound ~with_degree_bound:[]

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
      x )
    f ()

let bits_to_bytes bits =
  let byte_of_bits bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
        if b then acc lor (1 lsl i) else acc )
    |> Char.of_int_exn
  in
  List.map (List.groupi bits ~break:(fun i _ _ -> i mod 8 = 0)) ~f:byte_of_bits
  |> String.of_char_list

let group_map m ~a ~b =
  let params = Group_map.Params.create m { a; b } in
  stage (fun x -> Group_map.to_group m ~params x)

module Shifts = struct
  let tock1 : Backend.Tock.Field.t Shifted_value.Type1.Shift.t =
    Shifted_value.Type1.Shift.create (module Backend.Tock.Field)

  let tock2 : Backend.Tock.Field.t Shifted_value.Type2.Shift.t =
    Shifted_value.Type2.Shift.create (module Backend.Tock.Field)

  let tick1 : Backend.Tick.Field.t Shifted_value.Type1.Shift.t =
    Shifted_value.Type1.Shift.create (module Backend.Tick.Field)

  let tick2 : Backend.Tick.Field.t Shifted_value.Type2.Shift.t =
    Shifted_value.Type2.Shift.create (module Backend.Tick.Field)
end

module Lookup_parameters = struct
  let tick_zero : _ Composition_types.Zero_values.t =
    { value =
        { challenge = Challenge.Constant.zero
        ; scalar =
            Shifted_value.Type2.Shifted_value Impls.Wrap.Field.Constant.zero
        }
    ; var =
        { challenge = Impls.Step.Field.zero
        ; scalar =
            Shifted_value.Type2.Shifted_value
              (Impls.Step.Field.zero, Impls.Step.Boolean.false_)
        }
    }

  let tock_zero : _ Composition_types.Zero_values.t =
    { value =
        { challenge = Challenge.Constant.zero
        ; scalar =
            Shifted_value.Type2.Shifted_value Impls.Wrap.Field.Constant.zero
        }
    ; var =
        { challenge = Impls.Wrap.Field.zero
        ; scalar = Shifted_value.Type2.Shifted_value Impls.Wrap.Field.zero
        }
    }

  let tick ~lookup:flag : _ Composition_types.Wrap.Lookup_parameters.t =
    { use = No; zero = tick_zero }
end

let finite_exn : 'a Kimchi_types.or_infinity -> 'a * 'a = function
  | Finite (x, y) ->
      (x, y)
  | Infinity ->
      invalid_arg "finite_exn"

let or_infinite_conv :
    ('a * 'a) Pickles_types.Or_infinity.t -> 'a Kimchi_types.or_infinity =
  function
  | Finite (x, y) ->
      Finite (x, y)
  | Infinity ->
      Infinity

module Ipa = struct
  (* TODO: Make all this completely generic over backend *)

  let compute_challenge (type f) ~endo_to_field
      (module Field : Kimchi_backend.Field.S with type t = f) c =
    endo_to_field c

  let compute_challenges ~endo_to_field field chals =
    Vector.map chals ~f:(fun prechallenge ->
        Bulletproof_challenge.pack prechallenge
        |> compute_challenge field ~endo_to_field )

  module Wrap = struct
    let field =
      (module Backend.Tock.Field : Kimchi_backend.Field.S
        with type t = Backend.Tock.Field.t )

    let endo_to_field = Endo.Step_inner_curve.to_field

    let compute_challenge c = compute_challenge field ~endo_to_field c

    let compute_challenges cs = compute_challenges field ~endo_to_field cs

    let compute_sg chals =
      let comm =
        Kimchi_bindings.Protocol.SRS.Fq.b_poly_commitment
          (Backend.Tock.Keypair.load_urs ())
          (Pickles_types.Vector.to_array (compute_challenges chals))
      in
      comm.unshifted.(0) |> finite_exn
  end

  module Step = struct
    let field =
      (module Backend.Tick.Field : Kimchi_backend.Field.S
        with type t = Backend.Tick.Field.t )

    let endo_to_field = Endo.Wrap_inner_curve.to_field

    let compute_challenge c = compute_challenge field ~endo_to_field c

    let compute_challenges cs = compute_challenges field ~endo_to_field cs

    let compute_sg chals =
      let comm =
        Kimchi_bindings.Protocol.SRS.Fp.b_poly_commitment
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
            Pickles_types.Or_infinity.Finite comm )
      in
      let urs = Backend.Tick.Keypair.load_urs () in
      Promise.run_in_thread (fun () ->
          Kimchi_bindings.Protocol.SRS.Fp.batch_accumulator_check urs
            (Array.map comms ~f:or_infinite_conv)
            chals )
  end
end

let tock_unpadded_public_input_of_statement prev_statement =
  let input =
    let (T (typ, _conv, _conv_inv)) = Impls.Wrap.input () in
    Impls.Wrap.generate_public_input typ prev_statement
  in
  List.init
    (Backend.Tock.Field.Vector.length input)
    ~f:(Backend.Tock.Field.Vector.get input)

let tock_public_input_of_statement s = tock_unpadded_public_input_of_statement s

let tick_public_input_of_statement ~max_proofs_verified ~uses_lookup
    (prev_statement : _ Types.Step.Statement.t) =
  let input =
    let (T (input, _conv, _conv_inv)) =
      Impls.Step.input ~proofs_verified:max_proofs_verified
        ~wrap_rounds:Backend.Tock.Rounds.n ~uses_lookup
    in
    Impls.Step.generate_public_input input prev_statement
  in
  List.init
    (Backend.Tick.Field.Vector.length input)
    ~f:(Backend.Tick.Field.Vector.get input)

let max_quot_size ~of_int ~mul:( * ) ~sub:( - ) domain_size =
  of_int 5 * (domain_size - of_int 1)

let max_quot_size_int = max_quot_size ~of_int:Fn.id ~mul:( * ) ~sub:( - )

let ft_comm ~add:( + ) ~scale ~endoscale ~negate
    ~verification_key:(m : _ Pickles_types.Plonk_verification_key_evals.t)
    ~alpha
    ~(plonk : _ Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t)
    ~t_comm =
  let ( * ) x g = scale g x in
  let _, [ sigma_comm_last ] =
    Vector.split m.sigma_comm
      (snd (Pickles_types.Plonk_types.Permuts_minus_1.add Nat.N1.n))
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
      let (generic_selector :: l1 :: r1 :: o1 :: m1 :: l2 :: r2 :: o2 :: m2 :: _)
          =
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

let combined_evaluation (type f)
    (module Impl : Snarky_backendless.Snark_intf.Run with type field = f)
    ~(xi : Impl.Field.t) (without_degree_bound : _ list) =
  let open Impl in
  let open Field in
  let mul_and_add ~(acc : Field.t) ~(xi : Field.t)
      (fx : (Field.t, Boolean.var) Pickles_types.Plonk_types.Opt.t) : Field.t =
    match fx with
    | None ->
        acc
    | Some fx ->
        fx + (xi * acc)
    | Maybe (b, fx) ->
        Field.if_ b ~then_:(fx + (xi * acc)) ~else_:acc
  in
  with_label __LOC__ (fun () ->
      Pickles_types.Pcs_batch.combine_split_evaluations ~mul_and_add
        ~init:(function
          | Some x ->
              x
          | None ->
              Field.zero
          | Maybe (b, x) ->
              (b :> Field.t) * x )
        ~xi without_degree_bound )
