open Async_kernel
open Core_kernel
open Protocols.Coda_pow
open Coda_base
open Signature_lib

(** [Stubs] is a set of modules used for testing different components of tfc  *)
module Time = Coda_base.Block_time

module State_proof = struct
  include Coda_base.Proof

  let verify _ _ = return true
end

module Ledger_proof_statement = Transaction_snark.Statement

module Ledger_proof = struct
  type t = Ledger_proof_statement.t * Sok_message.Digest.Stable.V1.t
  [@@deriving sexp, bin_io]

  let underlying_proof (_ : t) = Proof.dummy

  let statement ((t, _) : t) : Ledger_proof_statement.t = t

  let statement_target (t : Ledger_proof_statement.t) = t.target

  let sok_digest (_, d) = d

  let dummy =
    ( Ledger_proof_statement.gen |> Quickcheck.random_value
    , Sok_message.Digest.default )

  let create ~statement ~sok_digest ~proof:_ = (statement, sok_digest)
end

module Ledger_proof_verifier = struct
  let verify _ _ ~message:_ = return true
end

module Staged_ledger_aux_hash = struct
  include Staged_ledger_hash.Aux_hash.Stable.V1

  let of_bytes = Staged_ledger_hash.Aux_hash.of_bytes
end

module Transaction_snark_work =
  Staged_ledger.Make_completed_work (Public_key.Compressed) (Ledger_proof)
    (Ledger_proof_statement)

module User_command = struct
  include (
    User_command :
      module type of User_command
      with module With_valid_signature := User_command.With_valid_signature )

  let fee (t : t) = Payload.fee t.payload

  let sender (t : t) = Signature_lib.Public_key.compress t.sender

  let seed = Secure_random.string ()

  module With_valid_signature = struct
    module T = struct
      include User_command.With_valid_signature

      let compare t1 t2 = User_command.With_valid_signature.compare ~seed t1 t2
    end

    include T
    include Comparable.Make (T)
  end
end

module Staged_ledger_diff = Staged_ledger.Make_diff (struct
  module Fee_transfer = Fee_transfer
  module Ledger_proof = Ledger_proof
  module Ledger_hash = Ledger_hash
  module Staged_ledger_hash = Staged_ledger_hash
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  module Compressed_public_key = Public_key.Compressed
  module User_command = User_command
  module Transaction_snark_work = Transaction_snark_work
end)

module External_transition =
  Coda_base.External_transition.Make
    (Staged_ledger_diff)
    (Consensus.Protocol_state)

module Transaction = struct
  module T = struct
    type t = Coda_base.Transaction.t =
      | User_command of User_command.With_valid_signature.t
      | Fee_transfer of Fee_transfer.t
      | Coinbase of Coinbase.t
    [@@deriving compare, eq]
  end

  include T

  include (
    Coda_base.Transaction :
      module type of Coda_base.Transaction with type t := t )
end

module Staged_ledger = Staged_ledger.Make (struct
  module Compressed_public_key = Signature_lib.Public_key.Compressed
  module User_command = User_command
  module Fee_transfer = Coda_base.Fee_transfer
  module Coinbase = Coda_base.Coinbase
  module Transaction = Transaction
  module Ledger_hash = Coda_base.Ledger_hash
  module Frozen_ledger_hash = Coda_base.Frozen_ledger_hash
  module Ledger_proof_statement = Ledger_proof_statement
  module Proof = Proof
  module Sok_message = Coda_base.Sok_message
  module Ledger_proof = Ledger_proof
  module Ledger_proof_verifier = Ledger_proof_verifier
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  module Staged_ledger_hash = Coda_base.Staged_ledger_hash
  module Transaction_snark_work = Transaction_snark_work
  module Staged_ledger_diff = Staged_ledger_diff
  module Account = Coda_base.Account
  module Ledger = Coda_base.Ledger
  module Sparse_ledger = Coda_base.Sparse_ledger
  module Transaction_validator = Coda_base.Transaction_validator

  module Config = struct
    let transaction_capacity_log_2 = 7

    let work_delay_factor = 2
  end
end)

(* Generate valid payments for each blockchain state by having
  each user send a payment of one coin to another random
   user if they at least one coin*)
let gen_payments ledger : User_command.With_valid_signature.t Sequence.t =
  let accounts_with_secret_keys = Genesis_ledger.accounts in
  let public_keys =
    List.map accounts_with_secret_keys ~f:(fun (_, account) ->
        Account.public_key account )
  in
  Sequence.filter_map (accounts_with_secret_keys |> Sequence.of_list)
    ~f:(fun (sender_sk, _) ->
      let open Option.Let_syntax in
      let%bind sender_sk = sender_sk in
      let ({Keypair.public_key= sender_pk; _} as sender_keypair) =
        Keypair.of_private_key_exn sender_sk
      in
      let status, sender_account_location =
        Coda_base.Ledger.get_or_create_account_exn ledger
          (Public_key.compress sender_pk)
          Account.empty
      in
      assert (status = `Existed) ;
      let%bind sender_account =
        Coda_base.Ledger.get ledger sender_account_location
      in
      let%bind receiver_pk = List.random_element public_keys in
      let send_amount = Currency.Amount.of_int 1 in
      let sender_account_amount =
        Account.balance sender_account |> Currency.Balance.to_amount
      in
      let%map _ = Currency.Amount.sub sender_account_amount send_amount in
      let payload : User_command.Payload.t =
        User_command.Payload.create ~fee:Fee.Unsigned.zero
          ~nonce:(Account.nonce sender_account)
          ~memo:User_command_memo.dummy
          ~body:(Payment {receiver= receiver_pk; amount= send_amount})
      in
      User_command.sign sender_keypair payload )

module Blockchain_state = External_transition.Protocol_state.Blockchain_state
module Protocol_state = External_transition.Protocol_state

module Transition_frontier_inputs = struct
  module Staged_ledger_aux_hash = Staged_ledger_aux_hash
  module Ledger_proof_statement = Ledger_proof_statement
  module Ledger_proof = Ledger_proof
  module Transaction_snark_work = Transaction_snark_work
  module Staged_ledger_diff = Staged_ledger_diff
  module External_transition = External_transition
  module Staged_ledger = Staged_ledger
end

module Transition_frontier =
  Transition_frontier.Make (Transition_frontier_inputs)

let gen_breadcrumb ~logger :
    (   Transition_frontier.Breadcrumb.t Deferred.t
     -> Transition_frontier.Breadcrumb.t Deferred.t)
    Quickcheck.Generator.t =
  let open Quickcheck.Let_syntax in
  let gen_slot_advancement = Int.gen_incl 1 10 in
  let%map make_next_consensus_state =
    Consensus.For_tests.gen_consensus_state ~gen_slot_advancement
  in
  fun parent_breadcrumb_deferred ->
    let open Deferred.Let_syntax in
    let%bind parent_breadcrumb = parent_breadcrumb_deferred in
    let parent_staged_ledger =
      Transition_frontier.Breadcrumb.staged_ledger parent_breadcrumb
    in
    let transactions =
      gen_payments (Staged_ledger.ledger parent_staged_ledger)
    in
    let {Keypair.public_key= largest_account_public_key; _} =
      Genesis_ledger.largest_account_keypair_exn ()
    in
    let get_completed_work stmts =
      let {Keypair.public_key; _} = Keypair.create () in
      let prover = Public_key.compress public_key in
      Some
        { Transaction_snark_work.Checked.fee= Fee.Unsigned.of_int 1
        ; proofs=
            List.map stmts ~f:(fun stmt -> (stmt, Sok_message.Digest.default))
        ; prover }
    in
    let staged_ledger_diff =
      Staged_ledger.create_diff parent_staged_ledger ~logger
        ~self:(Public_key.compress largest_account_public_key)
        ~transactions_by_fee:transactions ~get_completed_work
    in
    let%bind ( `Hash_after_applying next_staged_ledger_hash
             , `Ledger_proof ledger_proof_opt
             , `Staged_ledger _ ) =
      Staged_ledger.apply_diff_unchecked parent_staged_ledger
        staged_ledger_diff
      |> Deferred.Or_error.ok_exn
    in
    let previous_transition_with_hash =
      Transition_frontier.Breadcrumb.transition_with_hash parent_breadcrumb
    in
    let previous_protocol_state =
      With_hash.data previous_transition_with_hash
      |> External_transition.Verified.protocol_state
    in
    let previous_ledger_hash =
      previous_protocol_state |> Protocol_state.blockchain_state
      |> Protocol_state.Blockchain_state.snarked_ledger_hash
    in
    let next_ledger_hash =
      Option.value_map ledger_proof_opt
        ~f:(fun (proof, _) ->
          Ledger_proof.statement proof |> Ledger_proof.statement_target )
        ~default:previous_ledger_hash
    in
    let next_blockchain_state =
      Blockchain_state.create_value ~timestamp:(Block_time.now ())
        ~snarked_ledger_hash:next_ledger_hash
        ~staged_ledger_hash:next_staged_ledger_hash
    in
    let previous_state_hash =
      Consensus.Protocol_state.hash previous_protocol_state
    in
    let consensus_state =
      make_next_consensus_state ~snarked_ledger_hash:previous_ledger_hash
        ~previous_protocol_state:
          With_hash.{data= previous_protocol_state; hash= previous_state_hash}
    in
    let protocol_state =
      Protocol_state.create_value ~previous_state_hash
        ~blockchain_state:next_blockchain_state ~consensus_state
    in
    let next_external_transition =
      External_transition.create ~protocol_state
        ~protocol_state_proof:Proof.dummy
        ~staged_ledger_diff:(Staged_ledger_diff.forget staged_ledger_diff)
    in
    (* We manually created a verified an external_transition *)
    let (`I_swear_this_is_safe_see_my_comment
          next_verified_external_transition) =
      External_transition.to_verified next_external_transition
    in
    let next_verified_external_transition_with_hash =
      With_hash.of_data next_verified_external_transition
        ~hash_data:
          (Fn.compose Consensus.Protocol_state.hash
             External_transition.Verified.protocol_state)
    in
    match%map
      Transition_frontier.Breadcrumb.build ~logger ~parent:parent_breadcrumb
        ~transition_with_hash:next_verified_external_transition_with_hash
    with
    | Ok new_breadcrumb -> new_breadcrumb
    | Error (`Fatal_error exn) -> raise exn
    | Error (`Validation_error e) ->
        failwithf !"Validation Error : %{sexp:Error.t}" e ()

let create_root_frontier ~max_length ~logger : Transition_frontier.t Deferred.t
    =
  let accounts = Genesis_ledger.accounts in
  let _, proposer_account = List.hd_exn accounts in
  let root_snarked_ledger = Coda_base.Ledger.Db.create () in
  List.iter accounts ~f:(fun (_, account) ->
      let status, _ =
        Coda_base.Ledger.Db.get_or_create_account_exn root_snarked_ledger
          (Account.public_key account)
          account
      in
      assert (status = `Added) ) ;
  let root_transaction_snark_scan_state = Staged_ledger.Scan_state.empty () in
  let genesis_protocol_state =
    With_hash.data Consensus.genesis_protocol_state
  in
  let dummy_staged_ledger_diff =
    let creator =
      Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
    in
    { Staged_ledger_diff.diff=
        ( { completed_works= []
          ; user_commands= []
          ; coinbase= Staged_ledger_diff.At_most_two.Zero }
        , None )
    ; prev_hash= Coda_base.Staged_ledger_hash.dummy
    ; creator }
  in
  (* the genesis transition is assumed to be valid *)
  let (`I_swear_this_is_safe_see_my_comment root_transition) =
    External_transition.to_verified
      (External_transition.create ~protocol_state:genesis_protocol_state
         ~protocol_state_proof:Proof.dummy
         ~staged_ledger_diff:dummy_staged_ledger_diff)
  in
  let root_transition_with_data =
    { With_hash.data= root_transition
    ; hash= With_hash.hash Consensus.genesis_protocol_state }
  in
  let frontier =
    Transition_frontier.create ~logger
      ~root_transition:root_transition_with_data ~root_snarked_ledger
      ~root_transaction_snark_scan_state ~max_length
      ~root_staged_ledger_diff:None
      ~consensus_local_state:
        (Consensus.Local_state.create
           (Some proposer_account.Account.public_key))
  in
  frontier

let build_frontier_randomly ~gen_root_breadcrumb_builder frontier :
    unit Deferred.t =
  let root_breadcrumb = Transition_frontier.root frontier in
  (* HACK: This removes the overhead of having to deal with the quickcheck generator monad *)
  let deferred_breadcrumbs =
    gen_root_breadcrumb_builder root_breadcrumb |> Quickcheck.random_value
  in
  Deferred.List.iter deferred_breadcrumbs ~f:(fun deferred_breadcrumb ->
      let%map breadcrumb = deferred_breadcrumb in
      Transition_frontier.add_breadcrumb_exn frontier breadcrumb )

module Protocol_state_validator = Protocol_state_validator.Make (struct
  include Transition_frontier_inputs
  module Time = Time
  module State_proof = State_proof
end)

module Sync_handler = Sync_handler.Make (struct
  include Transition_frontier_inputs
  module Transition_frontier = Transition_frontier
end)

module Network = struct
  type t =
    {logger: Logger.t; table: Transition_frontier.t Network_peer.Peer.Table.t}

  let create ~logger ~peers = {logger; table= peers}

  let random_peers _ = failwith "STUB: Network.random_peers"

  let catchup_transition _ = failwith "STUB: Network.catchup_transition"

  let get_ancestry {table; _} peer (descendent, count) =
    (let open Option.Let_syntax in
    let%bind frontier = Hashtbl.find table peer in
    Sync_handler.prove_ancestry ~frontier count descendent)
    |> Result.of_option ~error:(Error.of_string "Mock Network error")
    |> Deferred.return

  let glue_sync_ledger {table; logger} query_reader response_writer : unit =
    Pipe_lib.Linear_pipe.iter_unordered ~max_concurrency:8 query_reader
      ~f:(fun (ledger_hash, sync_ledger_query) ->
        Logger.info logger
          !"Processing ledger query : %{sexp:(Ledger.Addr.t \
            Syncable_ledger.query)}"
          sync_ledger_query ;
        let answer =
          Hashtbl.to_alist table
          |> List.find_map ~f:(fun (peer, frontier) ->
                 let open Option.Let_syntax in
                 let%map answer =
                   Sync_handler.answer_query ~frontier ledger_hash
                     sync_ledger_query
                 in
                 Envelope.Incoming.wrap ~data:answer ~sender:peer )
        in
        match answer with
        | None ->
            Logger.info logger
              !"Could not find an answer for : %{sexp:(Ledger.Addr.t \
                Syncable_ledger.query)}"
              sync_ledger_query ;
            Deferred.unit
        | Some answer ->
            Logger.info logger
              !"Found an answer for : %{sexp:(Ledger.Addr.t \
                Syncable_ledger.query)}"
              sync_ledger_query ;
            Pipe_lib.Linear_pipe.write response_writer answer )
    |> don't_wait_for
end
