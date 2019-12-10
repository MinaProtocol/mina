open Core
open Async
open Signature_lib
open Coda_base

(** For status *)
let txn_count = ref 0

let record_payment t (txn : User_command.t) account =
  let logger =
    Logger.extend
      (Coda_lib.top_level_logger t)
      [("coda_command", `String "Recording payment")]
  in
  let previous = account.Account.Poly.receipt_chain_hash in
  let receipt_chain_database = Coda_lib.receipt_chain_database t in
  match Receipt_chain_database.add receipt_chain_database ~previous txn with
  | `Ok hash ->
      Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ("user_command", User_command.to_yojson txn)
          ; ("receipt_chain_hash", Receipt.Chain_hash.to_yojson hash) ]
        "Added  payment $user_command into receipt_chain database. You should \
         wait for a bit to see your account's receipt chain hash update as \
         $receipt_chain_hash" ;
      hash
  | `Duplicate hash ->
      Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("user_command", User_command.to_yojson txn)]
        "Already sent transaction $user_command" ;
      hash
  | `Error_multiple_previous_receipts parent_hash ->
      Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:
          [ ( "parent_receipt_chain_hash"
            , Receipt.Chain_hash.to_yojson parent_hash )
          ; ( "previous_receipt_chain_hash"
            , Receipt.Chain_hash.to_yojson previous ) ]
        "A payment is derived from two different blockchain states \
         ($parent_receipt_chain_hash, $previous_receipt_chain_hash). \
         Receipt.Chain_hash is supposed to be collision resistant. This \
         collision should not happen." ;
      Core.exit 1

let is_valid_user_command _t (txn : User_command.t) account_opt =
  let remainder =
    let open Option.Let_syntax in
    let%bind account = account_opt
    and cost =
      let fee = txn.payload.common.fee in
      match txn.payload.body with
      | Stake_delegation (Set_delegate _) ->
          Some (Currency.Amount.of_fee fee)
      | Payment {amount; _} ->
          Currency.Amount.add_fee amount fee
    in
    Currency.Balance.sub_amount account.Account.Poly.balance cost
  in
  Option.is_some remainder

let schedule_user_command t (txn : User_command.t) account_opt :
    unit Or_error.t Deferred.t =
  (* FIXME #3457: return a status from Transaction_pool.add and use it instead
     of is_valid_user_command
  *)
  if not (is_valid_user_command t txn account_opt) then
    Deferred.return
    @@ Or_error.error_string "Invalid user command: account balance is too low"
  else
    let txn_pool = Coda_lib.transaction_pool t in
    let%map () = Network_pool.Transaction_pool.add txn_pool [txn] in
    let logger =
      Logger.extend
        (Coda_lib.top_level_logger t)
        [("coda_command", `String "scheduling a user command")]
    in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("user_command", User_command.to_yojson txn)]
      "Added transaction $user_command to transaction pool successfully" ;
    txn_count := !txn_count + 1 ;
    Or_error.return ()

let get_account t (addr : Public_key.Compressed.t) =
  let open Participating_state.Let_syntax in
  let%map ledger = Coda_lib.best_ledger t in
  let open Option.Let_syntax in
  let%bind loc = Ledger.location_of_key ledger addr in
  Ledger.get ledger loc

let get_accounts t =
  let open Participating_state.Let_syntax in
  let%map ledger = Coda_lib.best_ledger t in
  Ledger.to_list ledger

let string_of_public_key =
  Fn.compose Public_key.Compressed.to_base58_check Account.public_key

let get_public_keys t =
  let open Participating_state.Let_syntax in
  let%map account = get_accounts t in
  List.map account ~f:string_of_public_key

let get_keys_with_details t =
  let open Participating_state.Let_syntax in
  let%map accounts = get_accounts t in
  List.map accounts ~f:(fun account ->
      ( string_of_public_key account
      , account.Account.Poly.balance |> Currency.Balance.to_int
      , account.Account.Poly.nonce |> Account.Nonce.to_int ) )

let get_inferred_nonce_from_transaction_pool_and_ledger t
    (addr : Public_key.Compressed.t) =
  let transaction_pool = Coda_lib.transaction_pool t in
  let resource_pool =
    Network_pool.Transaction_pool.resource_pool transaction_pool
  in
  let pooled_transactions =
    Network_pool.Transaction_pool.Resource_pool.all_from_user resource_pool
      addr
  in
  let txn_pool_nonce =
    let nonces =
      List.map pooled_transactions
        ~f:(Fn.compose User_command.nonce User_command.forget_check)
    in
    (* The last nonce gives us the maximum nonce in the transaction pool *)
    List.last nonces
  in
  match txn_pool_nonce with
  | Some nonce ->
      Participating_state.Option.return (Account.Nonce.succ nonce)
  | None ->
      let open Participating_state.Option.Let_syntax in
      let%map account = get_account t addr in
      account.Account.Poly.nonce

let get_nonce t (addr : Public_key.Compressed.t) =
  let open Participating_state.Option.Let_syntax in
  let%map account = get_account t addr in
  account.Account.Poly.nonce

let send_user_command t (txn : User_command.t) =
  let public_key = Public_key.compress txn.sender in
  let open Participating_state.Let_syntax in
  let%map account_opt = get_account t public_key in
  let open Deferred.Or_error.Let_syntax in
  let%map () = schedule_user_command t txn account_opt in
  record_payment t txn (Option.value_exn account_opt)

let get_balance t (addr : Public_key.Compressed.t) =
  let open Participating_state.Option.Let_syntax in
  let%map account = get_account t addr in
  account.Account.Poly.balance

let get_trust_status t (ip_address : Unix.Inet_addr.Blocking_sexp.t) =
  let config = Coda_lib.config t in
  let trust_system = config.trust_system in
  Trust_system.lookup trust_system ip_address

let get_trust_status_all t =
  let config = Coda_lib.config t in
  let trust_system = config.trust_system in
  Trust_system.peer_statuses trust_system

let reset_trust_status t (ip_address : Unix.Inet_addr.Blocking_sexp.t) =
  let config = Coda_lib.config t in
  let trust_system = config.trust_system in
  Trust_system.reset trust_system ip_address

let replace_proposers keys pks =
  let kps =
    List.filter_map pks ~f:(fun pk ->
        let open Option.Let_syntax in
        let%map kps =
          Coda_lib.wallets keys |> Secrets.Wallets.find_unlocked ~needle:pk
        in
        (kps, pk) )
  in
  Coda_lib.replace_propose_keypairs keys
    (Keypair.And_compressed_pk.Set.of_list kps) ;
  kps |> List.map ~f:snd

let setup_user_command ~fee ~nonce ~valid_until ~memo ~sender_kp
    user_command_body =
  let payload =
    User_command.Payload.create ~fee ~nonce ~valid_until ~memo
      ~body:user_command_body
  in
  let signed_user_command = User_command.sign sender_kp payload in
  User_command.forget_check signed_user_command

module Receipt_chain_hash = struct
  (* Receipt.Chain_hash does not have bin_io *)
  include Receipt.Chain_hash.Stable.V1

  [%%define_locally
  Receipt.Chain_hash.(cons, empty)]
end

let verify_payment t (addr : Public_key.Compressed.Stable.Latest.t)
    (verifying_txn : User_command.t) (init_receipt, proof) =
  let open Participating_state.Let_syntax in
  let%map account = get_account t addr in
  let account = Option.value_exn account in
  let resulting_receipt = account.Account.Poly.receipt_chain_hash in
  let open Or_error.Let_syntax in
  let%bind (_ : Receipt.Chain_hash.t Non_empty_list.t) =
    Result.of_option
      (Receipt_chain_database.verify ~init:init_receipt proof resulting_receipt)
      ~error:(Error.createf "Merkle list proof of payment is invalid")
  in
  if List.exists proof ~f:(fun txn -> User_command.equal verifying_txn txn)
  then Ok ()
  else
    Or_error.errorf
      !"Merkle list proof does not contain payment %{sexp:User_command.t}"
      verifying_txn

(* TODO: Properly record receipt_chain_hash for multiple transactions. See #1143 *)
let schedule_user_commands t (txns : User_command.t list) :
    unit Deferred.t Participating_state.t =
  Participating_state.return
  @@
  let txn_pool = Coda_lib.transaction_pool t in
  let logger =
    Logger.extend
      (Coda_lib.top_level_logger t)
      [("coda_command", `String "scheduling a batch of user transactions")]
  in
  Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
    "batch-send-payments does not yet report errors" ;
  Network_pool.Transaction_pool.add txn_pool txns

let prove_receipt t ~proving_receipt ~resulting_receipt =
  let receipt_chain_database = Coda_lib.receipt_chain_database t in
  (* TODO: since we are making so many reads to `receipt_chain_database`,
     reads should be async to not get IO-blocked. See #1125 *)
  let result =
    Receipt_chain_database.prove receipt_chain_database ~proving_receipt
      ~resulting_receipt
  in
  Deferred.return result

let start_time = Time_ns.now ()

(* let clear_hist_status ~flag t = Perf_histograms.wipe () ; get_status ~flag t *)

module Subscriptions = struct
  let new_block t public_key =
    let subscription = Coda_lib.subscription t in
    Coda_lib.Subscriptions.add_block_subscriber subscription public_key

  let reorganization t =
    let subscription = Coda_lib.subscription t in
    Coda_lib.Subscriptions.add_reorganization_subscriber subscription
end

module For_tests = struct
  let get_all_user_commands coda public_key =
    let external_transition_database =
      Coda_lib.external_transition_database coda
    in
    let user_commands =
      List.concat_map
        ~f:
          (Fn.compose
             Auxiliary_database.Filtered_external_transition.user_commands
             With_hash.data)
      @@ Auxiliary_database.External_transition_database.get_all_values
           external_transition_database (Some public_key)
    in
    let participants_user_commands =
      User_command.filter_by_participant user_commands public_key
    in
    List.dedup_and_sort participants_user_commands
      ~compare:User_command.compare

  module Subscriptions = struct
    let new_user_commands coda public_key =
      Coda_lib.add_payment_subscriber coda public_key
  end
end
