open Core_kernel
open Mina_base

type invalid =
  [ `Invalid_keys of Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_signature of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_proof
  | `Missing_verification_key of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list ]
[@@deriving bin_io_unversioned, to_yojson]

let invalid_to_string (invalid : invalid) =
  let keys_to_string keys =
    List.map keys ~f:(fun key ->
        Signature_lib.Public_key.Compressed.to_base58_check key )
    |> String.concat ~sep:";"
  in
  match invalid with
  | `Invalid_keys keys ->
      sprintf "Invalid_keys: [%s]" (keys_to_string keys)
  | `Invalid_signature keys ->
      sprintf "Invalid_signature: [%s]" (keys_to_string keys)
  | `Missing_verification_key keys ->
      sprintf "Missing_verification_key: [%s]" (keys_to_string keys)
  | `Invalid_proof ->
      "Invalid_proof"

let check :
       User_command.Verifiable.t
    -> [ `Valid of User_command.Valid.t
       | `Valid_assuming of User_command.Valid.t * _ list
       | invalid ] = function
  | User_command.Signed_command c -> (
      if not (Signed_command.check_valid_keys c) then
        `Invalid_keys (Signed_command.public_keys c)
      else
        match Signed_command.check_only_for_signature c with
        | Some c ->
            `Valid (User_command.Signed_command c)
        | None ->
            `Invalid_signature (Signed_command.public_keys c) )
  | Zkapp_command ({ fee_payer; account_updates; memo } as zkapp_command_with_vk)
    ->
      with_return (fun { return } ->
          let account_updates_hash =
            Zkapp_command.Call_forest.hash account_updates
          in
          let tx_commitment =
            Zkapp_command.Transaction_commitment.create ~account_updates_hash
          in
          let full_tx_commitment =
            Zkapp_command.Transaction_commitment.create_complete tx_commitment
              ~memo_hash:(Signed_command_memo.hash memo)
              ~fee_payer_hash:
                (Zkapp_command.Digest.Account_update.create
                   (Account_update.of_fee_payer fee_payer) )
          in
          let check_signature s pk msg =
            match Signature_lib.Public_key.decompress pk with
            | None ->
                return (`Invalid_keys [ pk ])
            | Some pk ->
                if
                  not
                    (Signature_lib.Schnorr.Chunked.verify s
                       (Backend.Tick.Inner_curve.of_affine pk)
                       (Random_oracle_input.Chunked.field msg) )
                then
                  return
                    (`Invalid_signature [ Signature_lib.Public_key.compress pk ])
                else ()
          in
          check_signature fee_payer.authorization fee_payer.body.public_key
            full_tx_commitment ;
          let zkapp_command_with_hashes_list =
            account_updates |> Zkapp_statement.zkapp_statements_of_forest'
            |> Zkapp_command.Call_forest.With_hashes_and_data
               .to_zkapp_command_with_hashes_list
          in
          let valid_assuming =
            List.filter_map zkapp_command_with_hashes_list
              ~f:(fun ((p, (vk_opt, stmt)), _at_account_update) ->
                let commitment =
                  if p.body.use_full_commitment then full_tx_commitment
                  else tx_commitment
                in
                match p.authorization with
                | Signature s ->
                    check_signature s p.body.public_key commitment ;
                    None
                | None_given ->
                    None
                | Proof pi -> (
                    match vk_opt with
                    | None ->
                        return
                          (`Missing_verification_key
                            [ Account_id.public_key
                              @@ Account_update.account_id p
                            ] )
                    | Some (vk : _ With_hash.t) ->
                        Some (vk.data, stmt, pi) ) )
          in
          let v : User_command.Valid.t =
            (*Verification keys should be present if it reaches here*)
            let zkapp_command =
              Option.value_exn
                (Zkapp_command.Valid.of_verifiable zkapp_command_with_vk)
            in
            User_command.Poly.Zkapp_command zkapp_command
          in
          match valid_assuming with
          | [] ->
              `Valid v
          | _ :: _ ->
              `Valid_assuming (v, valid_assuming) )
