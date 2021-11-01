open Core_kernel
open Mina_base

type invalid =
  [ `Invalid_keys of Signature_lib.Public_key.Compressed.Stable.Latest.t list
  | `Invalid_signature
  | `Invalid_proof
  | `Missing_verification_key ]
[@@deriving bin_io_unversioned]

let invalid_to_string (invalid : invalid) =
  match invalid with
  | `Invalid_keys keys ->
      sprintf "Invalid_keys: [%s]"
        ( List.map keys ~f:(fun key ->
              Signature_lib.Public_key.Compressed.to_base58_check key)
        |> String.concat ~sep:";" )
  | `Invalid_signature ->
      "Invalid_signature"
  | `Invalid_proof ->
      "Invalid_proof"
  | `Missing_verification_key ->
      "Missing_verification_key"

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
            `Invalid_signature )
  | Parties { fee_payer; other_parties; protocol_state; memo } ->
      with_return (fun { return } ->
          let commitment =
            let other_parties_hash =
              Parties.Party_or_stack.With_hashes.stack_hash other_parties
            in
            Parties.Transaction_commitment.create ~other_parties_hash
              ~protocol_state_predicate_hash:
                (Snapp_predicate.Protocol_state.digest protocol_state)
              ~memo_hash:(Signed_command_memo.hash memo)
          in
          let check_signature s pk msg =
            match Signature_lib.Public_key.decompress pk with
            | None ->
                return (`Invalid_keys [ pk ])
            | Some pk ->
                if
                  not
                    (Signature_lib.Schnorr.verify s
                       (Backend.Tick.Inner_curve.of_affine pk)
                       (Random_oracle_input.field msg))
                then return `Invalid_signature
                else ()
          in
          check_signature fee_payer.authorization fee_payer.data.body.pk
            (Parties.Transaction_commitment.with_fee_payer commitment
               ~fee_payer_hash:
                 (Party.Predicated.digest
                    (Party.Predicated.of_fee_payer fee_payer.data))) ;
          let parties_with_hashes_list =
            Parties.Party_or_stack.With_hashes.to_parties_with_hashes_list
              other_parties
          in
          let valid_assuming =
            List.filter_map parties_with_hashes_list
              ~f:(fun ((p, vk_opt), at_party) ->
                match p.authorization with
                | Signature s ->
                    check_signature s p.data.body.pk commitment ;
                    None
                | None_given ->
                    None
                | Proof pi -> (
                    match vk_opt with
                    | None ->
                        return `Missing_verification_key
                    | Some vk ->
                        Some
                          ( vk
                          , { Snapp_statement.Poly.transaction = commitment
                            ; at_party
                            }
                          , pi ) ))
          in
          let v =
            User_command.Poly.Parties
              { Parties.fee_payer
              ; other_parties =
                  List.map parties_with_hashes_list ~f:(fun ((p, _), _) -> p)
              ; protocol_state
              ; memo
              }
          in
          match valid_assuming with
          | [] ->
              `Valid v
          | _ :: _ ->
              `Valid_assuming (v, valid_assuming))
