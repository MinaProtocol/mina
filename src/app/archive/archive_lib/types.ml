open Core
open Coda_base
open Coda_state
open Coda_transition
open Graphql_query.Base_types

(** Library used to encode and decode types to a graphql format.

    Unfortunately, the graphql_ppx does not have an "encode" attribute that
    allows us to map an OCaml type into some graphql schema type in a clean
    way. Therefore, we have to make our own encode and decode functions. On top
    of this, the generated GraphQL schema constructed by Hasura creates insert
    methods where the fields for each argument are optional, even though the
    inputs are explicitly labeled as NOT NULL in Postgres.Therefore, we are
    forced to lift the option types to these nested types. Furthermore, some
    types that are in Postgres but are not GraphQL primitive types are treated
    as custom scalars. These types include `bigint`, `bit(n)` and enums.
    graphql_ppx treats custom scalars as Yojson.Basic.t types (usually they are
    encoded as Json string types).

    **)

let encode_as_obj_rel_insert_input data
    (on_conflict : ('constraint_, 'update_columns) Ast.On_conflict.t) =
  object
    method data = data

    method on_conflict = Some on_conflict
  end

let encode_as_arr_rel_insert_input data
    (on_conflict : ('constraint_, 'update_columns) Ast.On_conflict.t) =
  object
    method data = Array.of_list data

    method on_conflict = Some on_conflict
  end

module Public_key = struct
  let encode public_key =
    object
      method blocks = None

      method receiver_for_fee_transfers = None

      method snark_jobs = None

      method receiver_for_user_commands = None

      method sender_for_user_commands = None

      method value =
        Option.some
        @@ Signature_lib.Public_key.Compressed.to_base58_check public_key
    end

  let encode_as_obj_rel_insert_input public_key =
    encode_as_obj_rel_insert_input (encode public_key)
      Ast.On_conflict.public_keys
end

module User_command = struct
  let receiver user_command =
    match (User_command.payload user_command).body with
    | Payment payment ->
        payment.receiver
    | Stake_delegation (Set_delegate delegation) ->
        Account_id.create delegation.new_delegate Token_id.default

  let encode {With_hash.data= user_command; hash} first_seen =
    let payload = User_command.payload user_command in
    let body = payload.body in
    let open Option in
    object
      method hash = some @@ Transaction_hash.to_base58_check hash

      method blocks = None

      method amount =
        some
        @@ Amount.serialize
             ( match body with
             | Payment payment ->
                 payment.amount
             | Stake_delegation _ ->
                 Currency.Amount.zero )

      method fee = some @@ Fee.serialize (User_command.fee user_command)

      (* TODO: Enable when supported in transaction snark. *)
      (*method fee_token =
        Token_id.to_string @@ Account_id.token_id
        @@ User_command_payload.fee_token payload*)
      method first_seen = Option.map first_seen ~f:Block_time.serialize

      method memo =
        some @@ User_command_memo.to_string
        @@ User_command_payload.memo payload

      method nonce =
        some @@ Nonce.serialize @@ User_command_payload.nonce payload

      method sender =
        some @@ Public_key.encode_as_obj_rel_insert_input
        @@ Account_id.public_key
        @@ User_command.fee_payer user_command

      method receiver =
        some @@ Public_key.encode_as_obj_rel_insert_input
        @@ Account_id.public_key @@ receiver user_command

      method typ =
        some
        @@ User_command_type.encode
             ( match body with
             | Payment _ ->
                 `Payment
             | Stake_delegation _ ->
                 `Delegation )
    end

  let encode_as_obj_rel_insert_input user_command_with_hash first_seen =
    encode_as_obj_rel_insert_input
      (encode user_command_with_hash first_seen)
      Ast.On_conflict.user_commands

  let decode obj =
    let receiver = (obj#receiver)#value in
    let signer = (obj#sender)#value in
    let body =
      match obj#typ with
      | `Delegation ->
          User_command.Payload.Body.Stake_delegation
            (Set_delegate {new_delegate= receiver})
      | `Payment ->
          (* TODO: Allow GraphQL to send tokens other than the default. *)
          User_command.Payload.Body.Payment
            { receiver= Account_id.create receiver Token_id.default
            ; amount= obj#amount }
    in
    let payload =
      User_command_payload.create ~fee:obj#fee ~nonce:obj#nonce
        ~memo:
          obj#memo
          (* TODO: Allow GraphQL to send tokens other than the default. *)
        ~fee_token:Token_id.default
        ~body (* TODO: We should actually be passing obj#valid_until *)
        ~valid_until:Coda_numbers.Global_slot.max_value
    in
    ( Coda_base.{User_command.Poly.Stable.V1.payload; signer; signature= ()}
    , obj#first_seen )
end

module Fee_transfer = struct
  let encode {With_hash.data: Fee_transfer.Single.t = (receiver, fee); hash}
      first_seen =
    let open Option in
    object
      method hash = some @@ Transaction_hash.to_base58_check hash

      method fee = some @@ Fee.serialize fee

      method first_seen = Option.map first_seen ~f:Block_time.serialize

      method receiver =
        some @@ Public_key.encode_as_obj_rel_insert_input receiver

      method blocks = None
    end

  let encode_as_obj_rel_insert_input fee_transfer_with_hash first_seen =
    encode_as_obj_rel_insert_input
      (encode fee_transfer_with_hash first_seen)
      Ast.On_conflict.fee_transfers
end

module Snark_job = struct
  let encode ({fee; prover; work_ids; _} : Transaction_snark_work.Info.t) =
    let open Option in
    let job1, job2 =
      match work_ids with
      | `One job1 ->
          (Some job1, None)
      | `Two (job1, job2) ->
          (Some job1, Some job2)
    in
    object
      method blocks = None

      method fee = some @@ Fee.serialize fee

      method job1 = job1

      method job2 = job2

      method prover = some @@ Public_key.encode_as_obj_rel_insert_input prover
    end

  let encode_as_obj_rel_insert_input transaction_snark_work =
    encode_as_obj_rel_insert_input
      (encode transaction_snark_work)
      Ast.On_conflict.snark_jobs
end

module Receipt_chain_hash = struct
  type t = {value: Receipt.Chain_hash.t; parent: Receipt.Chain_hash.t}

  let to_obj value parent =
    object
      method hash = value

      method parent = parent

      method block = None
    end

  let encode t =
    let open Option in
    let parent =
      to_obj (some @@ Receipt.Chain_hash.to_string @@ t.parent) None
    in
    let value = some @@ Receipt.Chain_hash.to_string @@ t.value in
    let encoded_receipt_chain =
      to_obj value
        ( some
        @@ encode_as_obj_rel_insert_input parent
             Ast.On_conflict.receipt_chain_hash )
    in
    encode_as_obj_rel_insert_input encoded_receipt_chain
      Ast.On_conflict.receipt_chain_hash
end

module Blocks_user_commands = struct
  let encode user_command_with_hash first_seen receipt_chain_opt =
    object
      method block = None

      method receipt_chain_hash =
        Option.map receipt_chain_opt ~f:Receipt_chain_hash.encode

      method user_command =
        Some
          (User_command.encode_as_obj_rel_insert_input user_command_with_hash
             first_seen)
    end

  let encode_as_arr_rel_insert_input user_commands =
    encode_as_arr_rel_insert_input
      (List.map user_commands
         ~f:(fun (user_command_with_hash, first_seen, receipt_chain) ->
           encode user_command_with_hash first_seen receipt_chain ))
      Ast.On_conflict.blocks_user_commands
end

module Blocks_fee_transfers = struct
  let encode fee_transfer first_seen =
    object
      method block = None

      method fee_transfer =
        Some
          (Fee_transfer.encode_as_obj_rel_insert_input fee_transfer first_seen)
    end

  let encode_as_arr_rel_insert_input fee_transfers =
    encode_as_arr_rel_insert_input
      (List.map fee_transfers ~f:(fun (fee_transfers_with_hash, first_seen) ->
           encode fee_transfers_with_hash first_seen ))
      Ast.On_conflict.blocks_fee_transfers
end

module Blocks_snark_job = struct
  let encode snark_job =
    let obj =
      object
        method block = None

        method snark_job =
          Option.some @@ Snark_job.encode_as_obj_rel_insert_input snark_job
      end
    in
    obj

  let encode_as_arr_rel_insert_input snark_jobs =
    encode_as_arr_rel_insert_input
      (List.map snark_jobs ~f:encode)
      Ast.On_conflict.blocks_snark_jobs
end

module State_hashes = struct
  let encode state_hash =
    object
      method block = None

      method blocks = None

      method value = Some (State_hash.to_base58_check state_hash)
    end

  let encode_as_obj_rel_insert_input state_hash =
    encode_as_obj_rel_insert_input (encode state_hash)
      Ast.On_conflict.state_hashes
end

module Blocks = struct
  let serialize
      (With_hash.{hash; data= external_transition} :
        (External_transition.t, State_hash.t) With_hash.t)
      (user_commands :
        ( (Coda_base.User_command.t, Transaction_hash.t) With_hash.t
        * Coda_base.Block_time.t option
        * Receipt_chain_hash.t option )
        list)
      (fee_transfers :
        ( (Coda_base.Fee_transfer.Single.t, Transaction_hash.t) With_hash.t
        * Coda_base.Block_time.t option )
        list) =
    let blockchain_state =
      External_transition.blockchain_state external_transition
    in
    let consensus_state =
      External_transition.consensus_state external_transition
    in
    let consensus_time =
      Consensus.Data.Consensus_state.consensus_time consensus_state
    in
    let staged_ledger_diff =
      External_transition.staged_ledger_diff external_transition
    in
    let snark_jobs =
      List.map
        (Staged_ledger_diff.completed_works staged_ledger_diff)
        ~f:Transaction_snark_work.info
    in
    let open Option in
    object
      method state_hash =
        some @@ State_hashes.encode_as_obj_rel_insert_input hash

      method creator =
        some @@ Public_key.encode_as_obj_rel_insert_input
        @@ External_transition.block_producer external_transition

      method parent_hash =
        some @@ State_hashes.encode_as_obj_rel_insert_input
        @@ External_transition.parent_hash external_transition

      method snarked_ledger_hash =
        some @@ Ledger_hash.to_string @@ Frozen_ledger_hash.to_ledger_hash
        @@ Blockchain_state.snarked_ledger_hash blockchain_state

      method ledger_hash =
        some @@ Ledger_hash.to_string @@ Staged_ledger_hash.ledger_hash
        @@ Blockchain_state.staged_ledger_hash blockchain_state

      method global_slot =
        some @@ Unsigned.UInt32.to_int
        @@ Consensus.Data.Consensus_time.to_uint32 consensus_time

      (* TODO: Need to implement *)
      method ledger_proof_nonce = some 0

      (* When a new block is added, their status would be pending and its block
         confirmation number is 0 *)
      method status = some 0

      method block_length =
        some @@ Length.serialize
        @@ Consensus.Data.Consensus_state.blockchain_length consensus_state

      method block_time =
        some @@ Block_time.serialize
        @@ External_transition.timestamp external_transition

      method fee_transfers =
        some
        @@ Blocks_fee_transfers.encode_as_arr_rel_insert_input fee_transfers

      method snark_jobs =
        some @@ Blocks_snark_job.encode_as_arr_rel_insert_input snark_jobs

      method user_commands =
        some
        @@ Blocks_user_commands.encode_as_arr_rel_insert_input user_commands
    end
end
