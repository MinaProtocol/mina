open Core_kernel

type t = unit

(* Alias types with a [deriving to_yojson] annotation, so that we don't have to
   spell out the serialization explicitly.
*)
module Json = struct
  type 'f or_infinity = 'f Kimchi_types.or_infinity =
    | Infinity
    | Finite of ('f * 'f)
  [@@deriving to_yojson]

  type 'caml_g poly_comm = 'caml_g Kimchi_types.poly_comm =
    { unshifted : 'caml_g array; shifted : 'caml_g option }
  [@@deriving to_yojson]

  type lookup_patterns = Kimchi_types.lookup_patterns =
    { xor : bool; lookup : bool; range_check : bool; foreign_field_mul : bool }
  [@@deriving to_yojson]

  type lookup_features = Kimchi_types.lookup_features =
    { patterns : lookup_patterns
    ; joint_lookup_used : bool
    ; uses_runtime_tables : bool
    }
  [@@deriving to_yojson]

  type lookups_used = Kimchi_types.VerifierIndex.Lookup.lookups_used =
    | Single
    | Joint
  [@@deriving to_yojson]

  type lookup_info = Kimchi_types.VerifierIndex.Lookup.lookup_info =
    { max_per_row : int; max_joint_size : int; features : lookup_features }
  [@@deriving to_yojson]

  type 't lookup_selectors =
        't Kimchi_types.VerifierIndex.Lookup.lookup_selectors =
    { lookup : 't option
    ; xor : 't option
    ; range_check : 't option
    ; ffmul : 't option
    }
  [@@deriving to_yojson]

  type 'poly_comm lookup = 'poly_comm Kimchi_types.VerifierIndex.Lookup.t =
    { joint_lookup_used : bool
    ; lookup_table : 'poly_comm array
    ; lookup_selectors : 'poly_comm lookup_selectors
    ; table_ids : 'poly_comm option
    ; lookup_info : lookup_info
    ; runtime_tables_selector : 'poly_comm option
    }
  [@@deriving to_yojson]

  type 'fr domain = 'fr Kimchi_types.VerifierIndex.domain =
    { log_size_of_group : int; group_gen : 'fr }
  [@@deriving to_yojson]

  type 'poly_comm verification_evals =
        'poly_comm Kimchi_types.VerifierIndex.verification_evals =
    { sigma_comm : 'poly_comm array
    ; coefficients_comm : 'poly_comm array
    ; generic_comm : 'poly_comm
    ; psm_comm : 'poly_comm
    ; complete_add_comm : 'poly_comm
    ; mul_comm : 'poly_comm
    ; emul_comm : 'poly_comm
    ; endomul_scalar_comm : 'poly_comm
    }
  [@@deriving to_yojson]

  type ('fr, 'srs, 'poly_comm) verifier_index =
        ('fr, 'srs, 'poly_comm) Kimchi_types.VerifierIndex.verifier_index =
    { domain : 'fr domain
    ; max_poly_size : int
    ; public : int
    ; prev_challenges : int
    ; srs : 'srs
    ; evals : 'poly_comm verification_evals
    ; shifts : 'fr array
    ; lookup_index : 'poly_comm lookup option
    }
  [@@deriving to_yojson]

  let srs_to_yojson _ = `Null

  let step_verification_key_to_yojson =
    [%to_yojson:
      ( Backend.Tick.Field.t
      , srs
      , Backend.Tock.Field.t or_infinity poly_comm )
      verifier_index]

  let wrap_verification_key_to_yojson =
    [%to_yojson:
      ( Backend.Tock.Field.t
      , srs
      , Backend.Tick.Field.t or_infinity poly_comm )
      verifier_index]
end

let empty () = ()

let get_proof _t ~verification_key ~public_input =
  Format.eprintf "verification_key:@.%a@.public_input:@.%a@." Yojson.Safe.pp
    verification_key Yojson.Safe.pp public_input ;
  None

let get_step_proof t ~keypair ~public_input =
  let open Option.Let_syntax in
  let public_input =
    let len = Kimchi_bindings.FieldVectors.Fp.length public_input in
    Array.init len ~f:(fun i ->
        Kimchi_bindings.FieldVectors.Fp.get public_input i )
    |> [%to_yojson: Backend.Tick.Field.t array]
  in
  let verification_key =
    Backend.Tick.Keypair.vk keypair |> Json.step_verification_key_to_yojson
  in
  let%bind proof_json = get_proof t ~verification_key ~public_input in
  Option.try_with (fun () ->
      Result.ok_or_failwith @@ Backend.Tick.Proof.of_yojson proof_json )

let get_wrap_proof t ~keypair ~public_input =
  let open Option.Let_syntax in
  let public_input =
    let len = Kimchi_bindings.FieldVectors.Fq.length public_input in
    Array.init len ~f:(fun i ->
        Kimchi_bindings.FieldVectors.Fq.get public_input i )
    |> [%to_yojson: Backend.Tock.Field.t array]
  in
  let verification_key =
    Backend.Tock.Keypair.vk keypair |> Json.wrap_verification_key_to_yojson
  in
  let%bind proof_json = get_proof t ~verification_key ~public_input in
  Option.try_with (fun () ->
      Result.ok_or_failwith @@ Backend.Tock.Proof.of_yojson proof_json )

let set_proof _t ~verification_key ~public_input proof =
  Format.eprintf "verification_key:@.%a@.public_input:@.%a@.proof:@.%a@."
    Yojson.Safe.pp verification_key Yojson.Safe.pp public_input Yojson.Safe.pp
    proof ;
  ()

let set_step_proof t ~keypair ~public_input proof =
  let open Option.Let_syntax in
  let public_input =
    let len = Kimchi_bindings.FieldVectors.Fp.length public_input in
    Array.init len ~f:(fun i ->
        Kimchi_bindings.FieldVectors.Fp.get public_input i )
    |> [%to_yojson: Backend.Tick.Field.t array]
  in
  let verification_key =
    Backend.Tick.Keypair.vk keypair |> Json.step_verification_key_to_yojson
  in
  let proof_json = Backend.Tick.Proof.to_yojson proof in
  set_proof t ~verification_key ~public_input proof_json

let set_wrap_proof t ~keypair ~public_input proof =
  let open Option.Let_syntax in
  let public_input =
    let len = Kimchi_bindings.FieldVectors.Fq.length public_input in
    Array.init len ~f:(fun i ->
        Kimchi_bindings.FieldVectors.Fq.get public_input i )
    |> [%to_yojson: Backend.Tock.Field.t array]
  in
  let verification_key =
    Backend.Tock.Keypair.vk keypair |> Json.wrap_verification_key_to_yojson
  in
  let proof_json = Backend.Tock.Proof.to_yojson proof in
  set_proof t ~verification_key ~public_input proof_json
