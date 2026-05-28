(** Standalone kimchi prover for the in-circuit Schnorr verifier.
 *
 *  Mirrors `Pickles.Dump_circuit_impl.schnorr_verify_circuit` (which the
 *  PS-side `Snarky.Circuit.Schnorr.verifies` byte-matches) and produces:
 *    - `vk.serde.json`            — kimchi `VerifierIndex<Vesta>` serde
 *    - `proof.serde.json`         — kimchi `ProverProof<Vesta>` serde
 *    - `public_input.json`        — 6-element JSON array of hex Tick.Field
 *                                   values: pk_x, pk_y, r, s, message[0],
 *                                   plus the boolean output (`1`).
 *
 *  Iter-2b sign convention (matches `Data.Schnorr.sign` post-deterministic
 *  nonce + negate-k):
 *    1. Sample `d <- Pallas_scalar.random()`.
 *    2. Compute `pk = d·G`.
 *    3. `k' = Schnorr.Chunked.Message.derive ~signature_kind:Mainnet`
 *       — deterministic nonce from `(networkId, sk, pk, message)`.
 *    4. `R = k'·G`. If `R.y` is odd, set `k = -k'` (flips R.y's sign);
 *       else `k = k'`. Either way, the effective `R.y` is even, so the
 *       circuit's `y_even` assertion holds.
 *    5. `e_tick = Poseidon(pk.x, pk.y, R.x, message...)` (Mainnet-prefixed).
 *    6. Reject if `to_bigint(e_tick) >= 2^254` (scaleFast2' bound).
 *    7. `e_eff = e_pallas + 2^255`, `s_eff = k + d * e_eff`.
 *    8. `s_pallas = s_eff - 2^255`. Reject if `s_bigint >= 2^254`.
 *    9. Iter 2c lifts both 2^254 caps once `Snarky_curves.scale` lands.
 *
 *  On reject we re-sample `d` (the nonce is a deterministic function
 *  of `(sk, pk, message)`, so rotating `sk` is the only escape route).
 *
 *  Usage:
 *    dune exec src/lib/crypto/pickles/dump_schnorr_signature_proof/
 *              dump_schnorr_signature_proof.exe -- <output_dir>
 *)

open Core_kernel

module Tick = Pickles.Backend.Tick

(* Pallas curve module. *)
module Inner_curve = Pickles.Backend.Tick.Inner_curve

(* Pallas scalar field (Fq = Tock.Field). Has `to_bits`, `of_bits`,
   `random`, `to_bigint`, arithmetic. *)
module Pallas_scalar = Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field

(* Tick.Field directly, for `to_bigint` / `of_bits` / `unpack`. *)
module Tick_field = Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field

(* Step_impl = Tick on the snarky side; matches the `Impl` used by
   `Pickles.Dump_circuit_impl.schnorr_verify_circuit`. *)
module Impl = Kimchi_pasta_snarky_backend.Step_impl

(* `hash_prefix_states` transitively pulls in `crypto_params`, which
   sets the URS info at module init via `Cache_dir.cache`. Re-setting
   here would trip `Set_once.set_exn`, so we just let the
   crypto_params-driven init stand. *)


(* 2^255 in Pallas scalar; used for the circuit's `2^actual_bits_used`
   shift compensation. *)
let two_to_255_scalar : Pallas_scalar.t =
  let two = Pallas_scalar.of_int 2 in
  let rec pow n acc =
    if Int.equal n 0 then acc else pow (n - 1) Pallas_scalar.(acc * two)
  in
  pow 255 Pallas_scalar.one

(* Mainnet-prefixed Poseidon hash matching Mina's
   `Schnorr.Chunked.Message.hash` and the in-circuit
   `schnorr_verify_circuit`: seed sponge with
   `Hash_prefix_states.signature ~signature_kind:Mainnet`, absorb the
   inputs in order (message field-elements first on the caller side,
   then pk_x, pk_y, r — see `try_sign` below), squeeze. *)
let poseidon_hash (inputs : Tick_field.t array) : Tick_field.t =
  let init =
    Hash_prefix_states.signature ~signature_kind:Mina_signature_kind.Mainnet
  in
  let s = Random_oracle.update ~state:init inputs in
  Random_oracle.State.to_array s |> fun a -> a.(0)

(* Convert Tick.Field <-> Pallas.Scalar via bits. Safe when value <
   2^254 (both fields are 254-bit primes; bit list is size_in_bits). *)
let tick_to_pallas_scalar (x : Tick_field.t) : Pallas_scalar.t =
  Pallas_scalar.of_bits (Tick_field.to_bits x)

let pallas_scalar_to_tick (x : Pallas_scalar.t) : Tick_field.t =
  Tick_field.of_bits (Pallas_scalar.to_bits x)

(* Test bit 254 (top bit) — value >= 2^254 iff bit 254 is set. *)
let tick_field_ge_2_254 (x : Tick_field.t) : bool =
  let bits = Tick_field.to_bits x in
  match List.nth bits 254 with Some b -> b | None -> false

let pallas_scalar_ge_2_254 (x : Pallas_scalar.t) : bool =
  let bits = Pallas_scalar.to_bits x in
  match List.nth bits 254 with Some b -> b | None -> false

(* Returns `Some (rx, s_tick)` on success, `None` if the deterministic
   nonce hits the still-present `e >= 2^254` / `s >= 2^254` rejection
   branches. Caller resamples `d` (and re-derives the nonce) on `None`. *)
let try_sign ~(d : Pallas_scalar.t) ~(pk_point : Inner_curve.t)
    ~(pk_x : Tick_field.t) ~(pk_y : Tick_field.t)
    ~(message : Tick_field.t array) :
    (Tick_field.t * Tick_field.t) option =
  let t = Random_oracle.Input.Chunked.field_elements message in
  let k_prime =
    Signature_lib.Schnorr.Message.Chunked.derive
      ~signature_kind:Mina_signature_kind.Mainnet t ~private_key:d
      ~public_key:pk_point
  in
  let r_pt = Inner_curve.scale Inner_curve.one k_prime in
  let rx, ry = Inner_curve.to_affine_exn r_pt in
  let ry_bits = Tick_field.to_bits ry in
  let ry_even = match List.hd ry_bits with Some b -> not b | None -> true in
  (* Flip k's sign on ry-odd: `(-k)·G = (R.x, -R.y)`, and in a
     prime field of odd characteristic `-y` has the opposite parity. *)
  let k = if ry_even then k_prime else Pallas_scalar.(zero - k_prime) in
  (* Mina's `Schnorr.Chunked.Message.hash` order:
     `Input.Chunked.append message {pk; r}` — message field-elements
     first, then pk_x, pk_y, r. *)
  let hash_inputs = Array.concat [ message; [| pk_x; pk_y; rx |] ] in
  let e_tick = poseidon_hash hash_inputs in
  if tick_field_ge_2_254 e_tick then None
  else
    let e_pallas = tick_to_pallas_scalar e_tick in
    let e_eff = Pallas_scalar.(e_pallas + two_to_255_scalar) in
    let s_eff = Pallas_scalar.(k + (d * e_eff)) in
    let s_pallas = Pallas_scalar.(s_eff - two_to_255_scalar) in
    if pallas_scalar_ge_2_254 s_pallas then None
    else
      let s_tick = pallas_scalar_to_tick s_pallas in
      Some (rx, s_tick)

(* Iter-2b signer: derive is deterministic, so we vary `d` on rejection. *)
let sign_with_resample ~(message : Tick_field.t array) :
    Pallas_scalar.t * Tick_field.t * Tick_field.t * Tick_field.t * Tick_field.t
    =
  let rec loop attempt =
    if attempt > 200 then
      failwith "sign: exhausted rejection-sample budget (200 attempts)"
    else
      let d = Pallas_scalar.random () in
      let pk_point = Inner_curve.scale Inner_curve.one d in
      let pk_x, pk_y = Inner_curve.to_affine_exn pk_point in
      match try_sign ~d ~pk_point ~pk_x ~pk_y ~message with
      | Some (rx, s_tick) -> (d, pk_x, pk_y, rx, s_tick)
      | None -> loop (attempt + 1)
  in
  loop 0

(* Emit hex in LE byte order (no `~reverse`) so PS's `fromHexLe` parser
   reads it as little-endian, matching the kimchi-stubs/snarky-kimchi
   `_pallasScalarFieldFromHexLe` convention used elsewhere in the
   pipeline. OCaml's `Bigint.to_hex_string` uses `~reverse:true`
   (BE-ordered hex), which is incompatible with PS `fromHexLE`. *)
let field_to_hex_le (x : Tick_field.t) : string =
  let bytes = Tick_field.to_bigint x |> Kimchi_pasta_basic.Bigint256.to_bytes in
  let n = Bytes.length bytes in
  let buf = Buffer.create (2 * n) in
  for i = 0 to n - 1 do
    Buffer.add_string buf (Printf.sprintf "%02x" (Char.to_int (Bytes.get bytes i)))
  done ;
  Buffer.contents buf

let field_to_hex = field_to_hex_le

let write_public_input_json path (fields : Tick_field.t array) =
  let entries =
    Array.to_list fields
    |> List.map ~f:(fun f -> `String (field_to_hex f))
  in
  let json = `List entries in
  Out_channel.write_all path ~data:(Yojson.Safe.to_string json ^ "\n")

let () =
  let output_dir =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else "../packages/schnorr/test/fixtures/schnorr_signature_proof"
  in
  Printf.printf "dump_schnorr_signature_proof: output_dir = %s\n" output_dir ;

  (* 1. Sample a fresh message and run the deterministic-nonce signer.
     The signer rotates `d` (and re-derives the nonce) on the still-
     present `e/s >= 2^254` rejections. *)
  let message = [| Tick_field.random () |] in
  let _d, pk_x, pk_y, r, s = sign_with_resample ~message in
  Printf.printf "schnorr: signed message; pk.x (hex LE) = %s\n"
    (field_to_hex pk_x) ;
  Printf.printf "schnorr: r (hex LE) = %s\n  s (hex LE) = %s\n"
    (field_to_hex r) (field_to_hex s) ;

  (* 2. Compile the constraint system for the schnorr verifier. The
     typ is `(((Field*Field) * Field) * Field) * Field array (length 1)`,
     matching `Pickles.Dump_circuit_impl.schnorr_verify_circuit`'s
     function pattern. *)
  let schnorr_input_typ =
    let open Impl.Typ in
    let point = Impl.Field.typ * Impl.Field.typ in
    let msg = array ~length:1 Impl.Field.typ in
    point * Impl.Field.typ * Impl.Field.typ * msg
  in
  let constraint_system =
    Impl.constraint_system ~input_typ:schnorr_input_typ
      ~return_typ:Impl.Boolean.typ
      Pickles.Dump_circuit_impl.schnorr_verify_circuit
  in
  let proof_keypair =
    Tick.Keypair.create ~prev_challenges:0 constraint_system
  in
  let prover_index = Tick.Keypair.pk proof_keypair in
  let verifier_index = Tick.Keypair.vk proof_keypair in

  (* 3. Run the prover. `generate_witness_conv` threads inputs through
     the circuit to populate the public + auxiliary witnesses;
     `Tick.Proof.create_async` then produces the kimchi proof. *)
  let inputs :
      ( ( ( (Tick_field.t * Tick_field.t) * Tick_field.t)
        * Tick_field.t )
      * Tick_field.t array ) =
    ((((pk_x, pk_y), r), s), message)
  in
  let proof_high_level, bool_output =
    Impl.generate_witness_conv
      ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs } b_out ->
        let proof =
          Promise.block_on_async_exn (fun () ->
              Tick.Proof.create_async ~message:[] ~primary:public_inputs
                ~auxiliary:auxiliary_inputs prover_index )
        in
        (proof, b_out) )
      ~input_typ:schnorr_input_typ ~return_typ:Impl.Boolean.typ
      Pickles.Dump_circuit_impl.schnorr_verify_circuit
      inputs
  in
  Printf.printf "schnorr: generated kimchi proof (output=%b); serializing...\n"
    bool_output ;

  (* 4. Convert from the OCaml-side `with_public_evals` (which wraps
     `Plonk_types.Proof.t`) to the kimchi-protocol-level
     `Kimchi_types.proof_with_public` form that `to_serde_json`
     consumes. `primary_input` is left empty: serde skips the `public`
     field, and the PS verifier injects the 6-element public input via
     `set_public_` before calling `caml_pasta_fp_plonk_proof_verify`. *)
  let backend_proof =
    Tick.Proof.to_backend_with_public_evals' [] [||] proof_high_level
  in

  let vk_json =
    Kimchi_bindings.Protocol.VerifierIndex.Fp.to_serde_json verifier_index
  in
  Out_channel.write_all (output_dir ^ "/vk.serde.json") ~data:vk_json ;

  let proof_json =
    Kimchi_bindings.Protocol.Proof.Fp.to_serde_json backend_proof
  in
  Out_channel.write_all (output_dir ^ "/proof.serde.json") ~data:proof_json ;

  (* Public input = 6 field elements: the 5 verifier inputs in flat
     order plus the boolean output (`true` ⇒ `1`). Matches the kimchi
     fixture's `public_input_size = 6`. *)
  let bool_field =
    if bool_output then Tick_field.one else Tick_field.zero
  in
  write_public_input_json (output_dir ^ "/public_input.json")
    [| pk_x; pk_y; r; s; message.(0); bool_field |] ;

  Printf.printf
    "schnorr: wrote vk.serde.json + proof.serde.json + public_input.json\n"
