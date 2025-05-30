open Core_kernel
open Mina_base

type invalid =
  [ `Invalid_keys of Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_signature of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_proof of (Error.t[@to_yojson Error_json.error_to_yojson])
  | `Missing_verification_key of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Unexpected_verification_key of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Mismatched_authorization_kind of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list ]
[@@deriving bin_io_unversioned, to_yojson]

let invalid_to_error (invalid : invalid) : Error.t =
  let keys_to_string keys =
    List.map keys ~f:(fun key ->
        Signature_lib.Public_key.Compressed.to_base58_check key )
    |> String.concat ~sep:";"
  in
  match invalid with
  | `Invalid_keys keys ->
      Error.createf "Invalid_keys: [%s]" (keys_to_string keys)
  | `Invalid_signature keys ->
      Error.createf "Invalid_signature: [%s]" (keys_to_string keys)
  | `Missing_verification_key keys ->
      Error.createf "Missing_verification_key: [%s]" (keys_to_string keys)
  | `Unexpected_verification_key keys ->
      Error.createf "Unexpected_verification_key: [%s]" (keys_to_string keys)
  | `Mismatched_authorization_kind keys ->
      Error.createf "Mismatched_authorization_kind: [%s]" (keys_to_string keys)
  | `Invalid_proof err ->
      Error.tag ~tag:"Invalid_proof" err

let check_signed_command c =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  if not (Signed_command.check_valid_keys c) then
    Result.Error (`Invalid_keys (Signed_command.public_keys c))
  else
    match Signed_command.check_only_for_signature ~signature_kind c with
    | Some _ ->
        Result.Ok (`Assuming [])
    | None ->
        Result.Error (`Invalid_signature (Signed_command.public_keys c))

let collect_vk_assumption
    ( (p : (Account_update.Body.t, _ Control.Poly.t) Account_update.Poly.t)
    , ( (vk_opt :
          (Side_loaded_verification_key.t, Pasta_bindings.Fp.t) With_hash.t
          option )
      , (stmt : Zkapp_statement.t) ) ) =
  match (p.authorization, p.body.authorization_kind, vk_opt) with
  | Proof _, Proof _, None ->
      Error
        (`Missing_verification_key
          [ Account_id.public_key @@ Account_update.account_id p ] )
  | Proof pi, Proof vk_hash, Some (vk : _ With_hash.t) ->
      if
        (* check that vk expected for proof is the one being used *)
        Snark_params.Tick.Field.equal vk_hash (With_hash.hash vk)
      then Ok (Some (vk.data, stmt, pi))
      else
        Error
          (`Unexpected_verification_key
            [ Account_id.public_key @@ Account_update.account_id p ] )
  | _ ->
      Ok None

let collect_vk_assumptions zkapp_command =
  let collect_vk_assumption' collected (element, _) =
    let%map.Result res_opt = collect_vk_assumption element in
    Option.value_map ~f:(Fn.flip List.cons collected) ~default:collected res_opt
  in
  zkapp_command.Zkapp_command.Poly.account_updates
  |> Zkapp_statement.zkapp_statements_of_forest'
  |> Zkapp_command.Call_forest.With_hashes_and_data
     .to_zkapp_command_with_hashes_list
  |> List.fold_result ~f:collect_vk_assumption' ~init:[]

let check_signatures_of_zkapp_command (zkapp_command : _ Zkapp_command.Poly.t) :
    (unit, invalid) Result.t =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let account_updates_hash =
    Zkapp_command.Call_forest.hash
      zkapp_command.Zkapp_command.Poly.account_updates
  in
  let tx_commitment =
    Zkapp_command.Transaction_commitment.create ~account_updates_hash
  in
  let fee_payer = zkapp_command.fee_payer in
  let full_tx_commitment =
    Zkapp_command.Transaction_commitment.create_complete tx_commitment
      ~memo_hash:(Signed_command_memo.hash zkapp_command.memo)
      ~fee_payer_hash:
        (Zkapp_command.Digest.Account_update.create ~signature_kind
           (Account_update.of_fee_payer fee_payer) )
  in
  let check_signature s pk msg =
    let signature_kind = Mina_signature_kind.t_DEPRECATED in
    match Signature_lib.Public_key.decompress pk with
    | None ->
        Error (`Invalid_keys [ pk ])
    | Some pk ->
        if
          not
            (Signature_lib.Schnorr.Chunked.verify ~signature_kind s
               (Backend.Tick.Inner_curve.of_affine pk)
               (Random_oracle_input.Chunked.field msg) )
        then Error (`Invalid_signature [ Signature_lib.Public_key.compress pk ])
        else Ok ()
  in
  let%bind.Result () =
    check_signature fee_payer.authorization fee_payer.body.public_key
      full_tx_commitment
  in
  (* Check signatures *)
  Zkapp_command.Call_forest.to_list zkapp_command.account_updates
  |> List.fold_result ~init:() ~f:(fun () p ->
         let commitment =
           if Account_update.use_full_commitment p then full_tx_commitment
           else tx_commitment
         in
         match (p.authorization, p.body.authorization_kind) with
         | Control.Poly.Signature s, Signature ->
             check_signature s p.body.public_key commitment
         | None_given, None_given | Proof _, Proof _ ->
             Ok ()
         | _ ->
             Error
               (`Mismatched_authorization_kind
                 [ Account_id.public_key @@ Account_update.account_id p ] ) )

let check : _ With_status.t -> ([ `Assuming of _ list ], invalid) Result.t =
  function
  | { With_status.data = User_command.Signed_command c; status = _ } ->
      check_signed_command c
  | { With_status.data = Zkapp_command verifiable; status = Failed _ } ->
      let command = Zkapp_command.of_verifiable verifiable in
      let%map.Result () = check_signatures_of_zkapp_command command in
      `Assuming []
  | { With_status.data = Zkapp_command verifiable; status = Applied } ->
      let command = Zkapp_command.of_verifiable verifiable in
      let%bind.Result () = check_signatures_of_zkapp_command command in
      let%map.Result assuming = collect_vk_assumptions verifiable in
      `Assuming assuming

(** Verifies a command that is being held in mempool.
  * Function only assumes that `User_command.t` is held in the mempool,
  * additional checks are done on the `User_command.Verifiable.t` type to ensure
  * vallidity. *)
let verify_command_from_mempool
    (cmd_with_status : User_command.Verifiable.t With_status.t) =
  let coerce_cmd_as_valid cmd =
    (* NOTE:
       According to project https://www.notion.so/o1labs/Verification-of-zkapp-proofs-prior-to-block-creation-196e79b1f910807aa8aef723c135375a
       we consider a command in pool valid if either of the following holds:
         - It's failed
         - It's a signed command
         - It's a zkapp command, passing `collect_vk_assumptions` check
    *)
    let (`If_this_is_used_it_should_have_a_comment_justifying_it cmd_coerced) =
      User_command.(cmd |> of_verifiable |> to_valid_unsafe)
    in
    cmd_coerced
  in
  match cmd_with_status with
  | { status = Failed _; data = verifiable_cmd }
  | { data = Signed_command _ as verifiable_cmd; status = Applied } ->
      `Valid (coerce_cmd_as_valid verifiable_cmd)
  | { data = Zkapp_command zkapp_cmd as verifiable_cmd; status = Applied } -> (
      match collect_vk_assumptions zkapp_cmd with
      | Error e ->
          e
      | _ ->
          `Valid (coerce_cmd_as_valid verifiable_cmd) )
