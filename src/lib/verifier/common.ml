open Core_kernel
open Mina_base

type invalid =
  [ `Invalid_keys of Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_signature of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_proof
  | `Missing_verification_key of
    Signature_lib.Public_key.Compressed.Stable.Latest.t list ]
[@@deriving bin_io_unversioned]

let invalid_to_string (invalid : invalid) =
  let keys_to_string keys =
    List.map keys ~f:(fun key ->
        Signature_lib.Public_key.Compressed.to_base58_check key)
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
  | Parties { fee_payer; other_parties; memo } ->
      with_return (fun { return } ->
          let other_parties_hash = Parties.Call_forest.hash other_parties in
          let tx_commitment =
            Parties.Transaction_commitment.create ~other_parties_hash
              ~protocol_state_predicate_hash:
                (Snapp_predicate.Protocol_state.digest
                   fee_payer.data.body.protocol_state)
              ~memo_hash:(Signed_command_memo.hash memo)
          in
          let full_tx_commitment =
            Parties.Transaction_commitment.with_fee_payer tx_commitment
              ~fee_payer_hash:
                (Party.Predicated.digest
                   (Party.Predicated.of_fee_payer fee_payer.data))
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
                       (Random_oracle_input.Chunked.field msg))
                then
                  return
                    (`Invalid_signature
                      [ Signature_lib.Public_key.compress pk ])
                else ()
          in
          check_signature fee_payer.authorization fee_payer.data.body.public_key
            full_tx_commitment ;
          let parties_with_hashes_list =
            Parties.Call_forest.With_hashes.to_parties_with_hashes_list
              other_parties
          in
          let valid_assuming =
            List.filter_map parties_with_hashes_list
              ~f:(fun ((p, vk_opt), at_party) ->
                let commitment =
                  if p.data.body.use_full_commitment then full_tx_commitment
                  else tx_commitment
                in
                match p.authorization with
                | Signature s ->
                    check_signature s p.data.body.public_key commitment ;
                    None
                | None_given ->
                    None
                | Proof pi -> (
                    match vk_opt with
                    | None ->
                        return
                          (`Missing_verification_key
                            [ Account_id.public_key @@ Party.account_id p ])
                    | Some vk ->
                        let stmt =
                          { Snapp_statement.Poly.transaction = commitment
                          ; at_party
                          }
                        in
                        Some (vk, stmt, pi) ))
          in
          let v =
            User_command.Poly.Parties
              { Parties.fee_payer
              ; other_parties =
                  List.map parties_with_hashes_list ~f:(fun ((p, _), _) -> p)
              ; memo
              }
          in
          match valid_assuming with
          | [] ->
              `Valid v
          | _ :: _ ->
              `Valid_assuming (v, valid_assuming))
