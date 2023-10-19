open Core_kernel

[@@@warning "-4-27"]

module Yojson_map = Map.Make (struct
  type t =
    [ `Null
    | `Bool of bool
    | `Int of int
    | `Intlit of string
    | `Float of float
    | `String of string
    | `Assoc of (string * t) list
    | `List of t list
    | `Tuple of t list
    | `Variant of string * t option ]
  [@@deriving compare, sexp]
end)

[@@@warning "+4+27"]

type t = Yojson.Safe.t Yojson_map.t Yojson_map.t ref

(* We use a slightly more verbose format here, so that it's easy to debug.
   There are some overheads to handling this, but the amount of computation we
   save by caching the proofs is orders of magnitude higher, so it's not really
   an issue.
*)
let to_yojson t =
  `List
    (Map.fold ~init:[] !t ~f:(fun ~key ~data xs ->
         let proofs =
           Map.fold ~init:[] data ~f:(fun ~key ~data xs ->
               `Assoc [ ("public_input", key); ("proof", data) ] :: xs )
         in
         `Assoc [ ("verification_key", key); ("proofs", `List proofs) ] :: xs )
    )

(* This mirrors the format of [to_yojson], carefully ensuring that we can
   decode what we encode, and reporting an error when the format differs from
   what we expect.

   Note that, since this is a cache, it should always be possible to regenerate
   proofs for the cache by starting with the empty cache and calling
   [to_yojson] on the result.
*)
let of_yojson t =
  Result.try_with (fun () ->
      match t with
      | `List xs ->
          let for_vks =
            List.map xs ~f:(function
              | `Assoc [ ("verification_key", key); ("proofs", `List proofs) ]
                ->
                  let proofs =
                    List.map proofs ~f:(function
                      | `Assoc [ ("public_input", key); ("proof", data) ] ->
                          (key, data)
                      | _ ->
                          failwith
                            "Expected fields `public_input`, `proof` as a \
                             record in that order; received something \
                             different" )
                  in
                  (key, Yojson_map.of_alist_exn proofs)
              | _ ->
                  failwith
                    "Expected fields `verification_key`, `proofs` as a record \
                     in that order, where `proofs` is a list; received \
                     something different" )
          in
          ref (Yojson_map.of_alist_exn for_vks)
      | _ ->
          failwith "Expected a list, got something different" )
  |> Result.map_error ~f:Exn.to_string

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
    ; xor_comm : 'poly_comm option [@default None]
    ; range_check0_comm : 'poly_comm option [@default None]
    ; range_check1_comm : 'poly_comm option [@default None]
    ; foreign_field_add_comm : 'poly_comm option [@default None]
    ; foreign_field_mul_comm : 'poly_comm option [@default None]
    ; rot_comm : 'poly_comm option [@default None]
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
    ; zk_rows : int [@default 3]
    ; override_ffadd : bool [@default false]
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

let empty () = ref Yojson_map.empty

let get_proof t ~verification_key ~public_input =
  let open Option.Let_syntax in
  let%bind for_vk = Map.find !t verification_key in
  Map.find for_vk public_input

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

let set_proof t ~verification_key ~public_input proof =
  t :=
    Map.update !t verification_key ~f:(function
      | None ->
          Yojson_map.singleton public_input proof
      | Some for_vk ->
          Map.set for_vk ~key:public_input ~data:proof )

let set_step_proof t ~keypair ~public_input proof =
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

let is_env_var_set_requesting_error_for_proofs () =
  match Sys.getenv_opt "ERROR_ON_PROOF" with
  | Some ("true" | "t" (* insert whatever value is okay here *)) ->
      true
  | None | Some _ ->
      false
