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

let actual_wrap_domain_size ~log_2_domain_size =
  let d =
    match log_2_domain_size with
    | 13 ->
        0
    | 14 ->
        1
    | 15 ->
        2
    | _ ->
        assert false
  in
  Pickles_base.Proofs_verified.of_int d

let hash_messages_for_next_step_proof ~app_state
    (t : _ Types.Step.Proof_state.Messages_for_next_step_proof.t) =
  let g (x, y) = [ x; y ] in
  let open Backend in
  Tick_field_sponge.digest Tick_field_sponge.params
    (Types.Step.Proof_state.Messages_for_next_step_proof.to_field_elements t ~g
       ~comm:(fun (x : Tock.Curve.Affine.t) -> Array.of_list (g x))
       ~app_state )

let dlog_pcs_batch (type nat proofs_verified total)
    ((without_degree_bound, _pi) :
      total Nat.t * (proofs_verified, nat, total) Nat.Adds.t ) =
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
  let tock1 : Tock.Field.t Shifted_value.Type1.Shift.t =
    Shifted_value.Type1.Shift.create (module Tock.Field)

  let tock2 : Tock.Field.t Shifted_value.Type2.Shift.t =
    Shifted_value.Type2.Shift.create (module Tock.Field)

  let tick1 : Tick.Field.t Shifted_value.Type1.Shift.t =
    Shifted_value.Type1.Shift.create (module Tick.Field)

  let tick2 : Tick.Field.t Shifted_value.Type2.Shift.t =
    Shifted_value.Type2.Shift.create (module Tick.Field)
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
end

let finite_exn : 'a Kimchi_types.or_infinity -> 'a * 'a = function
  | Finite (x, y) ->
      (x, y)
  | Infinity ->
      invalid_arg "finite_exn"

let or_infinite_conv : ('a * 'a) Or_infinity.t -> 'a Kimchi_types.or_infinity =
  function
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
    Vector.map chals ~f:(fun prechallenge ->
        Bulletproof_challenge.pack prechallenge
        |> compute_challenge field ~endo_to_field )

  module Wrap = struct
    let field =
      (module Tock.Field : Kimchi_backend.Field.S with type t = Tock.Field.t)

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
      (module Tick.Field : Kimchi_backend.Field.S with type t = Tick.Field.t)

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
            Or_infinity.Finite comm )
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

let tick_public_input_of_statement ~max_proofs_verified ~feature_flags
    (prev_statement : _ Types.Step.Statement.t) =
  let input =
    let (T (input, _conv, _conv_inv)) =
      Impls.Step.input ~proofs_verified:max_proofs_verified
        ~wrap_rounds:Tock.Rounds.n ~feature_flags
    in
    Impls.Step.generate_public_input input prev_statement
  in
  List.init
    (Backend.Tick.Field.Vector.length input)
    ~f:(Backend.Tick.Field.Vector.get input)

let ft_comm ~add:( + ) ~scale ~endoscale ~negate
    ~verification_key:(m : _ Plonk_verification_key_evals.t) ~alpha
    ~(plonk : _ Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t)
    ~t_comm =
  let ( * ) x g = scale g x in
  let _, [ sigma_comm_last ] =
    Vector.split m.sigma_comm (snd (Plonk_types.Permuts_minus_1.add Nat.N1.n))
  in
  let f_comm = List.reduce_exn ~f:( + ) [ plonk.perm * sigma_comm_last ] in
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
      (fx : (Field.t, Boolean.var) Plonk_types.Opt.t) : Field.t =
    match fx with
    | None ->
        acc
    | Some fx ->
        fx + (xi * acc)
    | Maybe (b, fx) ->
        Field.if_ b ~then_:(fx + (xi * acc)) ~else_:acc
  in
  with_label __LOC__ (fun () ->
      Pcs_batch.combine_split_evaluations ~mul_and_add
        ~init:(function
          | Some x ->
              x
          | None ->
              Field.zero
          | Maybe (b, x) ->
              (b :> Field.t) * x )
        ~xi without_degree_bound )
