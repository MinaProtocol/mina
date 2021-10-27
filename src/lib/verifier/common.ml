open Core_kernel
open Mina_base

let check :
       User_command.Verifiable.t
    -> [ `Valid of User_command.Valid.t
       | `Invalid
       | `Valid_assuming of User_command.Valid.t * _ list ] = function
  | User_command.Signed_command c -> (
      match Signed_command.check c with
      | None ->
          `Invalid
      | Some c ->
          `Valid (User_command.Signed_command c) )
  | Parties ({ fee_payer; other_parties; protocol_state; memo } as p) ->
      with_return (fun { return } ->
          Core.printf "parties txn: %s\n%!"
            (Parties.Verifiable.to_yojson p |> Yojson.Safe.to_string) ;
          let other_parties_hash =
            Parties.Party_or_stack.With_hashes.stack_hash other_parties
          in
          let commitment =
            Parties.Transaction_commitment.create ~other_parties_hash
              ~protocol_state_predicate_hash:
                (Snapp_predicate.Protocol_state.digest protocol_state)
              ~memo_hash:(Signed_command_memo.hash memo)
          in
          let check_signature s pk msg =
            match Signature_lib.Public_key.decompress pk with
            | None ->
                Core.printf "Invalid key %s\n%!"
                  ( Signature_lib.Public_key.Compressed.to_yojson pk
                  |> Yojson.Safe.to_string ) ;
                return `Invalid
            | Some pk' ->
                if
                  not
                    (Signature_lib.Schnorr.verify s
                       (Backend.Tick.Inner_curve.of_affine pk')
                       (Random_oracle_input.field msg))
                then (
                  Core.printf "Invalid signature %s msg %s\n%!"
                    (Mina_base.Signature.to_base58_check s)
                    (Pickles.Backend.Tick.Field.to_string msg) ;
                  return `Invalid )
                else ()
          in
          Core.printf
            "otherparties hash: %s protocol hash: %s memo hash: %s fee_paer \
             hash: %s\n\
             %!"
            (Pickles.Backend.Tick.Field.to_string other_parties_hash)
            (Pickles.Backend.Tick.Field.to_string
               (Snapp_predicate.Protocol_state.digest protocol_state))
            (Pickles.Backend.Tick.Field.to_string
               (Signed_command_memo.hash memo))
            (Pickles.Backend.Tick.Field.to_string
               Party.Predicated.(digest (of_fee_payer fee_payer.data))) ;
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
                        (*TODO: should this return None?*)
                        Core.printf "No verification keys!\n%!" ;
                        return `Invalid
                    | Some vk ->
                        let stmt =
                          { Snapp_statement.Poly.transaction = commitment
                          ; at_party
                          }
                        in
                        Core.printf "snapp statement: %s\n%!"
                          (Snapp_statement.sexp_of_t stmt |> Sexp.to_string) ;
                        Some (vk, stmt, pi) ))
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
