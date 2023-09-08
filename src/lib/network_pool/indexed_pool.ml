(* See the .mli for a description of the purpose of this module. *)
open Core
open Mina_base
open Mina_transaction
open Mina_numbers

(* Fee increase required to replace a transaction. *)
let replace_fee : Currency.Fee.t = Currency.Fee.of_nanomina_int_exn 1

(* Invariants, maintained whenever a t is exposed from this module:
   * Iff a command is in all_by_fee it is also in all_by_sender.
   * Iff a command is in all_by_fee it is also in all_by_hash.
   * Iff a command is at the head of its sender's queue it is also in
     applicable_by_fee.
   * Sequences in all_by_sender are ordered by nonce and "dense".
   * Only commands with an expiration <> Global_slot_since_genesis.max_value is added to transactions_with_expiration.
   * There are no empty sets or sequences.
   * Fee indices are correct.
   * Total currency required is correct.
   * size = the sum of sizes of the sets in all_by_fee = the sum of the lengths
     of the queues in all_by_sender
*)

module Config = struct
  type t =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; consensus_constants : Consensus.Constants.t
    ; time_controller : Block_time.Controller.t
    ; slot_tx_end : Global_slot_since_hard_fork.t option
    }
  [@@deriving sexp_of, equal, compare]
end

type t =
  { applicable_by_fee :
      Transaction_hash.User_command_with_valid_signature.Set.t
      Currency.Fee_rate.Map.t
        (** Transactions valid against the current ledger, indexed by fee per
            weight unit. *)
  ; all_by_sender :
      ( Transaction_hash.User_command_with_valid_signature.t F_sequence.t
      * Currency.Amount.t )
      Account_id.Map.t
        (** All pending transactions along with the total currency required to
            execute them -- plus any currency spent from this account by
            transactions from other accounts -- indexed by sender account.
            Ordered by nonce inside the accounts. *)
  ; all_by_fee :
      Transaction_hash.User_command_with_valid_signature.Set.t
      Currency.Fee_rate.Map.t
        (** All transactions in the pool indexed by fee per weight unit. *)
  ; all_by_hash :
      Transaction_hash.User_command_with_valid_signature.t
      Transaction_hash.Map.t
  ; transactions_with_expiration :
      Transaction_hash.User_command_with_valid_signature.Set.t
      Global_slot_since_genesis.Map.t
        (*Only transactions that have an expiry*)
  ; size : int
  ; config : Config.t
  }
[@@deriving sexp_of, equal, compare]

let config t = t.config

(* Compute the total currency required from the sender to execute a command.
   Returns None in case of overflow.
*)
let currency_consumed_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> User_command.t
    -> Currency.Amount.t option =
 fun ~constraint_constants:_ cmd ->
  let fee_amt = Currency.Amount.of_fee @@ User_command.fee cmd in
  let open Currency.Amount in
  let amt =
    match cmd with
    | Signed_command c -> (
        match c.payload.body with
        | Payment { amount; _ } ->
            (* The fee-payer is also the sender account, include the amount. *)
            amount
        | Stake_delegation _ ->
            zero )
    | Zkapp_command _ ->
        (*TODO: document- txns succeeds with source amount insufficient in the case of zkapps*)
        zero
  in
  fee_amt + amt

let currency_consumed ~constraint_constants cmd =
  currency_consumed_unchecked ~constraint_constants
    (Transaction_hash.User_command_with_valid_signature.command cmd)

let currency_consumed' :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> User_command.t
    -> (Currency.Amount.t, Command_error.t) Result.t =
 fun ~constraint_constants cmd ->
  cmd
  |> currency_consumed_unchecked ~constraint_constants
  |> Result.of_option ~error:Command_error.Overflow

module For_tests = struct
  open Currency

  let currency_consumed = currency_consumed

  let applicable_by_fee { applicable_by_fee; _ } = applicable_by_fee

  let all_by_sender { all_by_sender; _ } = all_by_sender

  let assert_pool_consistency (pool : t) =
    let map_to_set (type k w)
        (module Map : Map.S
          with type Key.t = k
           and type Key.comparator_witness = w ) map =
      List.fold_left (Map.data map)
        ~init:Transaction_hash.User_command_with_valid_signature.Set.empty
        ~f:Set.union
    in
    let open Transaction_hash.User_command_with_valid_signature in
    let all_by_sender =
      Set.of_list
        (List.bind
           ~f:(fun (cmds, _) -> F_sequence.to_list cmds)
           (Account_id.Map.data pool.all_by_sender) )
    in
    let all_by_fee = map_to_set (module Fee_rate.Map) pool.all_by_fee in
    let all_by_hash =
      Set.of_list @@ Transaction_hash.Map.data pool.all_by_hash
    in
    let by_expiration =
      map_to_set
        (module Global_slot_since_genesis.Map)
        pool.transactions_with_expiration
    in
    let applicable_by_fee =
      map_to_set (module Fee_rate.Map) pool.applicable_by_fee
    in
    let all_txns =
      List.fold_left ~f:Set.union ~init:all_by_sender
        [ all_by_fee; all_by_hash; by_expiration; applicable_by_fee ]
    in
    [%test_eq: int] pool.size Set.(length all_txns) ;
    [%test_eq: Set.t] all_by_hash all_txns ;
    [%test_eq: Set.t] all_by_sender all_txns ;
    [%test_eq: Set.t] all_by_fee all_txns ;
    [%test_eq: Set.t]
      ( Account_id.Map.data pool.all_by_sender
      |> List.map ~f:(fun (cmds, _) -> F_sequence.head_exn cmds)
      |> Set.of_list )
      applicable_by_fee ;
    (* In each sender's queue nonces should be strictly increasing and the
       reserved currency should be equal to the sum of amounts and fees of
       all the commands in the queue. *)
    Account_id.Map.iteri pool.all_by_sender
      ~f:(fun ~key ~data:(queue, reserved_currency) ->
        [%test_pred:
          Transaction_hash.User_command_with_valid_signature.t F_sequence.t]
          (Fn.compose not F_sequence.is_empty)
          queue ;
        let _, reserved_currency' =
          F_sequence.foldl
            (fun (last_nonce, reserved) cmd ->
              let sender =
                Transaction_hash.User_command_with_valid_signature.command cmd
                |> User_command.fee_payer
              in
              [%test_eq: Account_id.t] sender key ;
              let nonce =
                Transaction_hash.User_command_with_valid_signature.command cmd
                |> User_command.applicable_at_nonce
              in
              [%test_pred: Account_nonce.t]
                (* Last nonce is None only at the very beginning. *)
                  (fun n ->
                  Option.value_map last_nonce ~default:true
                    ~f:Account_nonce.(( > ) n) )
                nonce ;
              let consumed =
                currency_consumed_unchecked
                  ~constraint_constants:pool.config.constraint_constants
                  (Transaction_hash.User_command_with_valid_signature.command
                     cmd )
                |> Option.value_exn
              in
              (Some nonce, Option.value_exn Amount.(reserved + consumed)) )
            (None, Currency.Amount.zero)
            queue
        in
        [%test_eq: Currency.Amount.t] reserved_currency reserved_currency' ) ;
    (* Check that commands are placed under correct keys. *)
    let check_fee fee cmd =
      [%test_eq: Currency.Fee_rate.t]
        (User_command.fee_per_wu
           (Transaction_hash.User_command_with_valid_signature.command cmd) )
        fee
    in
    let is_not_empty = Fn.compose not Set.is_empty in
    Currency.Fee_rate.Map.iteri pool.applicable_by_fee ~f:(fun ~key ~data ->
        [%test_pred: Set.t] is_not_empty data ;
        Set.iter data ~f:(check_fee key) ) ;
    Currency.Fee_rate.Map.iteri pool.all_by_fee ~f:(fun ~key ~data ->
        [%test_pred: Set.t] is_not_empty data ;
        Set.iter data ~f:(check_fee key) ) ;
    Transaction_hash.Map.iteri pool.all_by_hash ~f:(fun ~key ~data ->
        [%test_eq: Transaction_hash.t]
          (Transaction_hash.User_command_with_valid_signature.hash data)
          key )
end

let empty ~constraint_constants ~consensus_constants ~time_controller
    ~slot_tx_end : t =
  { applicable_by_fee = Currency.Fee_rate.Map.empty
  ; all_by_sender = Account_id.Map.empty
  ; all_by_fee = Currency.Fee_rate.Map.empty
  ; all_by_hash = Transaction_hash.Map.empty
  ; transactions_with_expiration = Global_slot_since_genesis.Map.empty
  ; size = 0
  ; config =
      { constraint_constants
      ; consensus_constants
      ; time_controller
      ; slot_tx_end
      }
  }

let size : t -> int = fun t -> t.size

(* The least fee per weight unit of all transactions in the transaction pool *)
let min_fee : t -> Currency.Fee_rate.t option =
 fun { all_by_fee; _ } -> Option.map ~f:Tuple2.get1 @@ Map.min_elt all_by_fee

let member : t -> Transaction_hash.User_command.t -> bool =
 fun t cmd ->
  Option.is_some
    (Map.find t.all_by_hash (Transaction_hash.User_command.hash cmd))

let has_commands_for_fee_payer : t -> Account_id.t -> bool =
 fun t account_id -> Map.mem t.all_by_sender account_id

let all_from_account :
       t
    -> Account_id.t
    -> Transaction_hash.User_command_with_valid_signature.t list =
 fun { all_by_sender; _ } account_id ->
  Option.value_map ~default:[] (Map.find all_by_sender account_id)
    ~f:(fun (user_commands, _) -> F_sequence.to_list user_commands)

let get_all { all_by_hash; _ } :
    Transaction_hash.User_command_with_valid_signature.t list =
  Map.data all_by_hash

let find_by_hash :
       t
    -> Transaction_hash.t
    -> Transaction_hash.User_command_with_valid_signature.t option =
 fun { all_by_hash; _ } hash -> Map.find all_by_hash hash

let global_slot_since_genesis conf =
  let current_time = Block_time.now conf.Config.time_controller in
  let current_slot =
    Consensus.Data.Consensus_time.(
      of_time_exn ~constants:conf.consensus_constants current_time
      |> to_global_slot)
  in
  match conf.constraint_constants.fork with
  | Some { previous_global_slot; _ } ->
      let slot_span =
        Mina_numbers.Global_slot_since_hard_fork.to_uint32 current_slot
        |> Mina_numbers.Global_slot_span.of_uint32
      in
      Mina_numbers.Global_slot_since_genesis.(
        add previous_global_slot slot_span)
  | None ->
      (* we're in the genesis "hard fork", so consider current slot as
         since-genesis
      *)
      Mina_numbers.Global_slot_since_hard_fork.to_uint32 current_slot
      |> Mina_numbers.Global_slot_since_genesis.of_uint32

let global_slot_since_hard_fork conf =
  let current_time = Block_time.now conf.Config.time_controller in
  Consensus.Data.Consensus_time.(
    of_time_exn ~constants:conf.consensus_constants current_time
    |> to_global_slot)

let slot_tx_end t = t.config.slot_tx_end

let check_expiry t (cmd : User_command.t) =
  let global_slot_since_genesis = global_slot_since_genesis t in
  let valid_until = User_command.valid_until cmd in
  if Global_slot_since_genesis.(valid_until < global_slot_since_genesis) then
    Error
      (Command_error.Expired
         ( `Valid_until valid_until
         , `Global_slot_since_genesis global_slot_since_genesis ) )
  else Ok ()

(* a cmd is in the transactions_with_expiration map only if it has an expiry*)
let update_expiration_map expiration_map cmd op =
  let user_cmd =
    Transaction_hash.User_command_with_valid_signature.command cmd
  in
  let expiry = User_command.valid_until user_cmd in
  if Global_slot_since_genesis.(expiry <> max_value) then
    match op with
    | `Add ->
        Map_set.insert
          (module Transaction_hash.User_command_with_valid_signature)
          expiration_map expiry cmd
    | `Del ->
        Map_set.remove_exn expiration_map expiry cmd
  else expiration_map

let remove_from_expiration_exn expiration_map cmd =
  update_expiration_map expiration_map cmd `Del

let add_to_expiration expiration_map cmd =
  update_expiration_map expiration_map cmd `Add

(* Remove a command from the applicable_by_fee field. This may break an
   invariant. *)
let remove_applicable_exn :
    t -> Transaction_hash.User_command_with_valid_signature.t -> t =
 fun t cmd ->
  let fee_per_wu =
    Transaction_hash.User_command_with_valid_signature.command cmd
    |> User_command.fee_per_wu
  in
  { t with
    applicable_by_fee = Map_set.remove_exn t.applicable_by_fee fee_per_wu cmd
  }

(* Remove a command from the all_by_fee and all_by_hash fields, and decrement
   size. This may break an invariant. *)
let remove_all_by_fee_and_hash_and_expiration_exn :
    t -> Transaction_hash.User_command_with_valid_signature.t -> t =
 fun t cmd ->
  let fee_per_wu =
    Transaction_hash.User_command_with_valid_signature.command cmd
    |> User_command.fee_per_wu
  in
  let cmd_hash = Transaction_hash.User_command_with_valid_signature.hash cmd in
  { t with
    all_by_fee = Map_set.remove_exn t.all_by_fee fee_per_wu cmd
  ; all_by_hash = Map.remove t.all_by_hash cmd_hash
  ; transactions_with_expiration =
      remove_from_expiration_exn t.transactions_with_expiration cmd
  ; size = t.size - 1
  }

module Sender_local_state = struct
  type t0 =
    { sender : Account_id.t
    ; data :
        ( Transaction_hash.User_command_with_valid_signature.t F_sequence.t
        * Currency.Amount.t )
        option
    }

  type t = (t0[@sexp.opaque]) [@@deriving sexp]

  let sender { sender; _ } = sender

  let to_yojson _ = `String "<per_sender>"

  let is_remove t = Option.is_none t.data
end

let set_sender_local_state (t : t) ({ sender; data } : Sender_local_state.t) : t
    =
  { t with
    all_by_sender = Map.change t.all_by_sender sender ~f:(fun _ -> data)
  }

let get_sender_local_state (t : t) sender : Sender_local_state.t =
  { sender; data = Map.find t.all_by_sender sender }

module Update = struct
  module F_seq = struct
    type 'a t = 'a F_sequence.t

    include
      Sexpable.Of_sexpable1
        (List)
        (struct
          type 'a t = 'a F_sequence.t

          let to_sexpable = F_sequence.to_list

          let of_sexpable xs =
            List.fold xs ~init:F_sequence.empty ~f:F_sequence.snoc
        end)
  end

  type single =
    | Add of
        { command : Transaction_hash.User_command_with_valid_signature.t
        ; fee_per_wu : Currency.Fee_rate.t
        ; add_to_applicable_by_fee : bool
        }
    | Remove_all_by_fee_and_hash_and_expiration of
        Transaction_hash.User_command_with_valid_signature.t F_seq.t
    | Remove_from_applicable_by_fee of
        { fee_per_wu : Currency.Fee_rate.t
        ; command : Transaction_hash.User_command_with_valid_signature.t
        }
  [@@deriving sexp]

  type t = single Writer_result.Tree.t (* [@sexp.opaque] *) [@@deriving sexp]

  let to_yojson _ = `String "<update>"

  let apply acc (u : single) =
    match u with
    | Add { command = cmd; fee_per_wu; add_to_applicable_by_fee } ->
        let acc =
          if add_to_applicable_by_fee then
            { acc with
              applicable_by_fee =
                Map_set.insert
                  (module Transaction_hash.User_command_with_valid_signature)
                  acc.applicable_by_fee fee_per_wu cmd
            }
          else acc
        in
        let cmd_hash =
          Transaction_hash.User_command_with_valid_signature.hash cmd
        in
        ( match Transaction_hash.User_command_with_valid_signature.data cmd with
        | Zkapp_command p ->
            let p = Zkapp_command.Valid.forget p in
            let updates, proof_updates =
              let init =
                match
                  (Account_update.of_fee_payer p.fee_payer).authorization
                with
                | Proof _ ->
                    (1, 1)
                | _ ->
                    (1, 0)
              in
              Zkapp_command.Call_forest.fold p.account_updates ~init
                ~f:(fun (count, proof_updates_count) account_update ->
                  ( count + 1
                  , if
                      Control.(
                        Tag.equal Proof
                          (tag (Account_update.authorization account_update)))
                    then proof_updates_count + 1
                    else proof_updates_count ) )
            in
            Mina_metrics.Counter.inc_one
              Mina_metrics.Transaction_pool.zkapp_transactions_added_to_pool ;
            Mina_metrics.Counter.inc
              Mina_metrics.Transaction_pool.zkapp_transaction_size
              (Zkapp_command.Stable.Latest.bin_size_t p |> Float.of_int) ;
            Mina_metrics.Counter.inc Mina_metrics.Transaction_pool.zkapp_updates
              (Float.of_int updates) ;
            Mina_metrics.Counter.inc
              Mina_metrics.Transaction_pool.zkapp_proof_updates
              (Float.of_int proof_updates)
        | Signed_command _ ->
            () ) ;
        { acc with
          all_by_fee =
            Map_set.insert
              (module Transaction_hash.User_command_with_valid_signature)
              acc.all_by_fee fee_per_wu cmd
        ; all_by_hash = Map.set acc.all_by_hash ~key:cmd_hash ~data:cmd
        ; transactions_with_expiration =
            add_to_expiration acc.transactions_with_expiration cmd
        ; size = acc.size + 1
        }
    | Remove_all_by_fee_and_hash_and_expiration cmds ->
        F_sequence.foldl
          (fun acc cmd -> remove_all_by_fee_and_hash_and_expiration_exn acc cmd)
          acc cmds
    | Remove_from_applicable_by_fee { fee_per_wu; command } ->
        { acc with
          applicable_by_fee =
            Map_set.remove_exn acc.applicable_by_fee fee_per_wu command
        }

  let apply (us : t) t = Writer_result.Tree.fold ~init:t us ~f:apply

  let merge (t1 : t) (t2 : t) = Writer_result.Tree.append t1 t2

  let empty : t = Empty
end

(* Returns a sequence of commands in the pool in descending fee order *)
let transactions ~logger t =
  let insert_applicable applicable_by_fee txn =
    let fee =
      User_command.fee_per_wu
      @@ Transaction_hash.User_command_with_valid_signature.command txn
    in
    Map.update applicable_by_fee fee ~f:(function
      | Some set ->
          Set.add set txn
      | None ->
          Transaction_hash.User_command_with_valid_signature.Set.singleton txn )
  in
  Sequence.unfold
    ~init:(t.applicable_by_fee, Map.map ~f:fst t.all_by_sender)
    ~f:(fun (applicable_by_fee, all_by_sender) ->
      if Map.is_empty applicable_by_fee then (
        assert (Map.is_empty all_by_sender) ;
        None )
      else
        let fee, set = Map.max_elt_exn applicable_by_fee in
        assert (Set.length set > 0) ;
        let txn = Set.min_elt_exn set in
        let applicable_by_fee' =
          let set' = Set.remove set txn in
          if Set.is_empty set' then Map.remove applicable_by_fee fee
          else Map.set applicable_by_fee ~key:fee ~data:set'
        in
        let applicable_by_fee'', all_by_sender' =
          let sender =
            User_command.fee_payer
            @@ Transaction_hash.User_command_with_valid_signature.command txn
          in
          let sender_queue = Map.find_exn all_by_sender sender in
          let head_txn, sender_queue' =
            Option.value_exn (F_sequence.uncons sender_queue)
          in
          if
            Transaction_hash.equal
              (Transaction_hash.User_command_with_valid_signature.hash txn)
              (Transaction_hash.User_command_with_valid_signature.hash head_txn)
          then
            match F_sequence.uncons sender_queue' with
            | Some (next_txn, _) ->
                ( insert_applicable applicable_by_fee' next_txn
                , Map.set all_by_sender ~key:sender ~data:sender_queue' )
            | None ->
                (applicable_by_fee', Map.remove all_by_sender sender)
          else (
            (* the sender's queue is malformed *)
            [%log error]
              "Transaction pool \"applicable_by_fee\" index contained \
               malformed entry for $sender ($head_applicable_by_fee != \
               $head_sender_queue); skipping transactions from $sender during \
               iteration"
              ~metadata:
                [ ("sender", Account_id.to_yojson sender)
                ; ( "head_applicable_by_fee"
                  , Transaction_hash.User_command_with_valid_signature.to_yojson
                      txn )
                ; ( "head_sender_queue"
                  , Transaction_hash.User_command_with_valid_signature.to_yojson
                      head_txn )
                ] ;
            (applicable_by_fee', Map.remove all_by_sender sender) )
        in
        Some (txn, (applicable_by_fee'', all_by_sender')) )

let run :
    type a e.
       sender:Account_id.t
    -> t
    -> (Sender_local_state.t ref -> (a, Update.single, e) Writer_result.t)
    -> (a * t, e) Result.t =
 fun ~sender t a ->
  let r = ref (get_sender_local_state t sender) in
  let res = Writer_result.run (a r) in
  Result.map res ~f:(fun (a, updates) ->
      let t = set_sender_local_state t !r in
      (a, Update.apply updates t) )

(* Remove a given command from the pool, as well as any commands that depend on
   it. Called from revalidate and remove_lowest_fee, and when replacing
   transactions. *)
let remove_with_dependents_exn :
       constraint_constants:_
    -> Transaction_hash.User_command_with_valid_signature.t
    -> Sender_local_state.t ref
    -> ( Transaction_hash.User_command_with_valid_signature.t Sequence.t
       , Update.single
       , _ )
       Writer_result.t =
 fun ~constraint_constants (* ({ constraint_constants; _ } as t) *) cmd state ->
  let unchecked =
    Transaction_hash.User_command_with_valid_signature.command cmd
  in
  let open Writer_result.Let_syntax in
  let sender_queue, reserved_currency = Option.value_exn !state.data in
  assert (not @@ F_sequence.is_empty sender_queue) ;
  let cmd_nonce =
    Transaction_hash.User_command_with_valid_signature.command cmd
    |> User_command.applicable_at_nonce
  in
  let cmd_index =
    F_sequence.findi sender_queue ~f:(fun cmd' ->
        let nonce =
          Transaction_hash.User_command_with_valid_signature.command cmd'
          |> User_command.applicable_at_nonce
        in
        (* we just compare nonce equality since the command we are looking for already exists in the sequence *)
        Account_nonce.equal nonce cmd_nonce )
    |> Option.value_exn
  in
  let keep_queue, drop_queue = F_sequence.split_at sender_queue cmd_index in
  assert (not (F_sequence.is_empty drop_queue)) ;
  let currency_to_remove =
    F_sequence.foldl
      (fun acc cmd' ->
        Option.value_exn
          (* safe because we check for overflow when we add commands. *)
          (let open Option.Let_syntax in
          let%bind consumed = currency_consumed ~constraint_constants cmd' in
          Currency.Amount.(consumed + acc)) )
      Currency.Amount.zero drop_queue
  in
  let reserved_currency' =
    (* This is safe because the currency in a subset of the commands much be <=
       total currency in all the commands. *)
    Option.value_exn Currency.Amount.(reserved_currency - currency_to_remove)
  in
  let%map () =
    Writer_result.write
      (Update.Remove_all_by_fee_and_hash_and_expiration drop_queue)
  and () =
    if cmd_index = 0 then
      Writer_result.write
        (Update.Remove_from_applicable_by_fee
           { fee_per_wu = User_command.fee_per_wu unchecked; command = cmd } )
    else Writer_result.return ()
  in
  state :=
    { !state with
      data =
        ( if not (F_sequence.is_empty keep_queue) then
          Some (keep_queue, reserved_currency')
        else (
          assert (Currency.Amount.(equal reserved_currency' zero)) ;
          None ) )
    } ;
  F_sequence.to_seq drop_queue

let run' t cmd x =
  run t
    ~sender:
      (User_command.fee_payer
         (Transaction_hash.User_command_with_valid_signature.command cmd) )
    x

let remove_with_dependents_exn' t cmd =
  match
    run' t cmd
      (remove_with_dependents_exn
         ~constraint_constants:t.config.constraint_constants cmd )
  with
  | Ok x ->
      x
  | Error _ ->
      failwith "remove_with_dependents_exn"

(** Drop commands from the end of the queue until the total currency consumed is
    <= the current balance. *)
let drop_until_sufficient_balance :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> Transaction_hash.User_command_with_valid_signature.t F_sequence.t
       * Currency.Amount.t
    -> Currency.Amount.t
    -> Transaction_hash.User_command_with_valid_signature.t F_sequence.t
       * Currency.Amount.t
       * Transaction_hash.User_command_with_valid_signature.t Sequence.t =
 fun ~constraint_constants (queue, currency_reserved) current_balance ->
  let rec go queue' currency_reserved' dropped_so_far =
    if Currency.Amount.(currency_reserved' <= current_balance) then
      (queue', currency_reserved', dropped_so_far)
    else
      let daeh, liat =
        Option.value_exn
          ~message:
            "couldn't drop any more transactions when trying to preserve \
             sufficient balance"
          (F_sequence.unsnoc queue')
      in
      let consumed =
        Option.value_exn (currency_consumed ~constraint_constants liat)
      in
      go daeh
        (Option.value_exn Currency.Amount.(currency_reserved' - consumed))
        (Sequence.append dropped_so_far @@ Sequence.singleton liat)
  in
  go queue currency_reserved Sequence.empty

let drop_all t =
  { t with
    applicable_by_fee = Currency.Fee_rate.Map.empty
  ; all_by_sender = Account_id.Map.empty
  ; all_by_fee = Currency.Fee_rate.Map.empty
  ; all_by_hash = Transaction_hash.Map.empty
  ; transactions_with_expiration = Global_slot_since_genesis.Map.empty
  ; size = 0
  }

(* Iterate over commands in the pool, removing them if they require too much
   currency or have too low of a nonce. An argument is provided to instruct
   which commands require revalidation.
*)
let revalidate :
       t
    -> logger:Logger.t
    -> [ `Entire_pool | `Subset of Account_id.Set.t ]
    -> (Account_id.t -> Account.t)
    -> t * Transaction_hash.User_command_with_valid_signature.t Sequence.t =
 fun ({ config = { constraint_constants; _ }; _ } as t) ~logger scope f ->
  let requires_revalidation =
    match scope with
    | `Entire_pool ->
        Fn.const true
    | `Subset subset ->
        Set.mem subset
  in
  Map.fold t.all_by_sender ~init:(t, Sequence.empty)
    ~f:(fun
         ~key:sender
         ~data:(queue, currency_reserved)
         ((t', dropped_acc) as acc)
       ->
      if not (requires_revalidation sender) then acc
      else
        let account : Account.t = f sender in
        let current_balance =
          Currency.Balance.to_amount
            (Account.liquid_balance_at_slot
               ~global_slot:(global_slot_since_genesis t.config)
               account )
        in
        [%log debug]
          "Revalidating account $account in transaction pool ($account_nonce, \
           $account_balance)"
          ~metadata:
            [ ( "account"
              , `String (Sexp.to_string @@ Account_id.sexp_of_t sender) )
            ; ("account_nonce", `Int (Account_nonce.to_int account.nonce))
            ; ( "account_balance"
              , `String (Currency.Amount.to_mina_string current_balance) )
            ] ;
        let first_cmd = F_sequence.head_exn queue in
        let first_nonce =
          first_cmd
          |> Transaction_hash.User_command_with_valid_signature.command
          |> User_command.applicable_at_nonce
        in
        if
          not
            ( Account.has_permission_to_send account
            && Account.has_permission_to_increment_nonce account )
        then (
          [%log debug]
            "Account no longer has permission to send; dropping queue" ;
          let dropped, t'' = remove_with_dependents_exn' t first_cmd in
          (t'', Sequence.append dropped_acc dropped) )
        else if Account_nonce.(account.nonce < first_nonce) then (
          [%log debug]
            "Current account nonce precedes first nonce in queue; dropping \
             queue" ;
          let dropped, t'' = remove_with_dependents_exn' t first_cmd in
          (t'', Sequence.append dropped_acc dropped) )
        else
          (* current_nonce >= first_nonce *)
          let first_applicable_nonce_index =
            F_sequence.findi queue ~f:(fun cmd' ->
                let nonce =
                  Transaction_hash.User_command_with_valid_signature.command
                    cmd'
                  |> User_command.applicable_at_nonce
                in
                Account_nonce.equal nonce account.nonce )
            |> Option.value ~default:(F_sequence.length queue)
          in
          [%log debug]
            "Current account nonce succeeds first nonce in queue; splitting \
             queue at $index"
            ~metadata:[ ("index", `Int first_applicable_nonce_index) ] ;
          let drop_queue, keep_queue =
            F_sequence.split_at queue first_applicable_nonce_index
          in
          let currency_reserved' =
            F_sequence.foldl
              (fun c cmd ->
                Option.value_exn
                  Currency.Amount.(
                    c
                    - Option.value_exn
                        (currency_consumed ~constraint_constants cmd)) )
              currency_reserved drop_queue
          in
          let keep_queue', currency_reserved'', dropped_for_balance =
            drop_until_sufficient_balance ~constraint_constants
              (keep_queue, currency_reserved')
              current_balance
          in
          let to_drop =
            Sequence.append (F_sequence.to_seq drop_queue) dropped_for_balance
          in
          match Sequence.next to_drop with
          | None ->
              acc
          | Some (head, tail) ->
              let t'' =
                Sequence.fold tail
                  ~init:
                    (remove_all_by_fee_and_hash_and_expiration_exn
                       (remove_applicable_exn t' head)
                       head )
                  ~f:remove_all_by_fee_and_hash_and_expiration_exn
              in
              let t''' =
                match F_sequence.uncons keep_queue' with
                | None ->
                    { t'' with
                      all_by_sender = Map.remove t''.all_by_sender sender
                    }
                | Some (first_kept, _) ->
                    let first_kept_unchecked =
                      Transaction_hash.User_command_with_valid_signature.command
                        first_kept
                    in
                    { t'' with
                      all_by_sender =
                        Map.set t''.all_by_sender ~key:sender
                          ~data:(keep_queue', currency_reserved'')
                    ; applicable_by_fee =
                        Map_set.insert
                          ( module Transaction_hash
                                   .User_command_with_valid_signature )
                          t''.applicable_by_fee
                          (User_command.fee_per_wu first_kept_unchecked)
                          first_kept
                    }
              in
              (t''', Sequence.append dropped_acc to_drop) )

let expired_by_global_slot (t : t) :
    Transaction_hash.User_command_with_valid_signature.t Sequence.t =
  let global_slot_since_genesis = global_slot_since_genesis t.config in
  let expired, _, _ =
    Map.split t.transactions_with_expiration global_slot_since_genesis
  in
  Map.to_sequence expired |> Sequence.map ~f:snd
  |> Sequence.bind ~f:Set.to_sequence

let expired (t : t) :
    Transaction_hash.User_command_with_valid_signature.t Sequence.t =
  [ expired_by_global_slot t ] |> Sequence.of_list |> Sequence.concat

let remove_expired t :
    Transaction_hash.User_command_with_valid_signature.t Sequence.t * t =
  Sequence.fold (expired t) ~init:(Sequence.empty, t) ~f:(fun acc cmd ->
      let dropped_acc, t = acc in
      (*[cmd] would not be in [t] if it depended on an expired transaction already handled*)
      if member t (Transaction_hash.User_command.of_checked cmd) then
        let removed, t' = remove_with_dependents_exn' t cmd in
        (Sequence.append dropped_acc removed, t')
      else acc )

let remove_lowest_fee :
    t -> Transaction_hash.User_command_with_valid_signature.t Sequence.t * t =
 fun t ->
  match Map.min_elt t.all_by_fee with
  | None ->
      (Sequence.empty, t)
  | Some (_min_fee, min_fee_set) ->
      remove_with_dependents_exn' t @@ Set.min_elt_exn min_fee_set

let get_highest_fee :
    t -> Transaction_hash.User_command_with_valid_signature.t option =
 fun t ->
  Option.map
    ~f:
      (Fn.compose
         Transaction_hash.User_command_with_valid_signature.Set.min_elt_exn
         Tuple2.get2 )
  @@ Currency.Fee_rate.Map.max_elt t.applicable_by_fee

(* Add a command that came in from gossip, or return an error. We need to check
   a whole bunch of conditions here and return the appropriate errors.
   Conditions:
   1. Command nonce must be >= account nonce.
   1a. If the sender's queue is empty, command nonce must equal account nonce.
   1b. If the sender's queue is non-empty, command nonce must be <= the nonce of
       the last queued command + 1
   2. The sum of the currency consumed by all queued commands for the sender
      must be <= the sender's balance.
   3. If a command is replaced, the new command must have a fee greater than the
      replaced command by at least replace fee * (number of commands after the
      the replaced command + 1)
   4. No integer overflows are allowed.
   5. protocol state predicate must be satisfiable before txs would expire
      from the pool based on age
   5a. timestamp predicate upper bound must be above current time.
   5b. timestamp predicate lower bound must be below current time plus expiration time,
       or the transaction will not become valid while in the pool
   These conditions are referenced in the comments below.
*)

module Add_from_gossip_exn (M : Writer_result.S) = struct
  let rec add_from_gossip_exn :
         config:Config.t
      -> Transaction_hash.User_command_with_valid_signature.t
      -> Account_nonce.t
      -> Currency.Amount.t
      -> Sender_local_state.t ref
      -> ( Transaction_hash.User_command_with_valid_signature.t
           * Transaction_hash.User_command_with_valid_signature.t Sequence.t
         , Update.single
         , Command_error.t )
         M.t =
   fun ~config:
         ( { constraint_constants; consensus_constants; time_controller; _ } as
         config ) cmd current_nonce balance by_sender ->
    let open Command_error in
    let current_global_slot =
      Consensus.Data.Consensus_time.(
        to_global_slot
          (of_time_exn ~constants:consensus_constants
             (Block_time.now time_controller) ))
    in
    match config.slot_tx_end with
    | Some slot_tx_end
      when Global_slot_since_hard_fork.(current_global_slot >= slot_tx_end) ->
        M.of_result (Error After_slot_tx_end)
    | Some _ | None -> (
        let unchecked_cmd = Transaction_hash.User_command.of_checked cmd in
        let open M.Let_syntax in
        let unchecked = Transaction_hash.User_command.data unchecked_cmd in
        let fee = User_command.fee unchecked in
        let fee_per_wu = User_command.fee_per_wu unchecked in
        let cmd_applicable_at_nonce =
          User_command.applicable_at_nonce unchecked
        in
        (* Result errors indicate problems with the command, while assert failures
           indicate bugs in Mina. *)
        let%bind consumed =
          M.of_result
            Result.Let_syntax.(
              (* C5 *)
              let%bind () = check_expiry config unchecked in
              let%bind consumed =
                currency_consumed' ~constraint_constants unchecked
              in
              let%map () =
                (* TODO: Proper exchange rate mechanism. *)
                let fee_token = User_command.fee_token unchecked in
                if Token_id.(equal default) fee_token then return ()
                else Error (Unwanted_fee_token fee_token)
              in
              consumed)
        in
        (* C4 *)
        match !by_sender.data with
        | None ->
            let%bind () =
              M.of_result
                Result.Let_syntax.(
                  (* nothing queued for this sender *)
                  let%bind () =
                    Result.ok_if_true
                      (Account_nonce.equal current_nonce cmd_applicable_at_nonce)
                      ~error:
                        (Invalid_nonce
                           (`Expected current_nonce, cmd_applicable_at_nonce) )
                    (* C1/1a *)
                  in
                  let%map () =
                    Result.ok_if_true
                      Currency.Amount.(consumed <= balance)
                      ~error:(Insufficient_funds (`Balance balance, consumed))
                    (* C2 *)
                  in
                  ())
            in
            let%map () =
              M.write
                (Update.Add
                   { command = cmd
                   ; fee_per_wu
                   ; add_to_applicable_by_fee = true
                   } )
            in
            by_sender :=
              { !by_sender with
                data = Some (F_sequence.singleton cmd, consumed)
              } ;
            (cmd, Sequence.empty)
        | Some (queued_cmds, reserved_currency) ->
            assert (not @@ F_sequence.is_empty queued_cmds) ;
            (* C1/C1b *)
            let queue_applicable_at_nonce =
              F_sequence.head_exn queued_cmds
              |> Transaction_hash.User_command_with_valid_signature.command
              |> User_command.applicable_at_nonce
            in
            let queue_target_nonce =
              F_sequence.last_exn queued_cmds
              |> Transaction_hash.User_command_with_valid_signature.command
              |> User_command.expected_target_nonce
            in
            if Account_nonce.equal queue_target_nonce cmd_applicable_at_nonce
            then (
              (* this command goes on the end *)
              let%bind reserved_currency' =
                M.of_result
                  ( Currency.Amount.(consumed + reserved_currency)
                  |> Result.of_option ~error:Overflow )
                (* C4 *)
              in
              let%bind () =
                M.of_result
                  (Result.ok_if_true
                     Currency.Amount.(reserved_currency' <= balance)
                     ~error:
                       (Insufficient_funds (`Balance balance, reserved_currency')
                       ) )
                (* C2 *)
              in
              let new_state =
                (F_sequence.snoc queued_cmds cmd, reserved_currency')
              in
              let%map () =
                M.write
                  (Update.Add
                     { command = cmd
                     ; fee_per_wu
                     ; add_to_applicable_by_fee = false
                     } )
              in
              by_sender := { !by_sender with data = Some new_state } ;
              (cmd, Sequence.empty) )
            else if Account_nonce.equal queue_applicable_at_nonce current_nonce
            then (
              (* we're replacing a command *)
              let%bind () =
                Result.ok_if_true
                  (Account_nonce.between ~low:queue_applicable_at_nonce
                     ~high:queue_target_nonce cmd_applicable_at_nonce )
                  ~error:
                    (Invalid_nonce
                       ( `Between (queue_applicable_at_nonce, queue_target_nonce)
                       , cmd_applicable_at_nonce ) )
                |> M.of_result
                (* C1/C1b *)
              in
              let replacement_index =
                F_sequence.findi queued_cmds ~f:(fun cmd' ->
                    let cmd_applicable_at_nonce' =
                      Transaction_hash.User_command_with_valid_signature.command
                        cmd'
                      |> User_command.applicable_at_nonce
                    in
                    Account_nonce.compare cmd_applicable_at_nonce
                      cmd_applicable_at_nonce'
                    <= 0 )
                |> Option.value_exn
              in
              let _keep_queue, drop_queue =
                F_sequence.split_at queued_cmds replacement_index
              in
              let to_drop =
                F_sequence.head_exn drop_queue
                |> Transaction_hash.User_command_with_valid_signature.command
              in
              assert (
                Account_nonce.compare cmd_applicable_at_nonce
                  (User_command.applicable_at_nonce to_drop)
                <= 0 ) ;
              (* We check the fee increase twice because we need to be sure the
                 subtraction is safe. *)
              let%bind () =
                let replace_fee = User_command.fee to_drop in
                Result.ok_if_true
                  Currency.Fee.(fee >= replace_fee)
                  ~error:
                    (Insufficient_replace_fee (`Replace_fee replace_fee, fee))
                |> M.of_result
                (* C3 *)
              in
              let%bind dropped =
                remove_with_dependents_exn ~constraint_constants
                  (F_sequence.head_exn drop_queue)
                  by_sender
                |> M.lift
              in
              (* check remove_exn dropped the right things *)
              [%test_eq:
                Transaction_hash.User_command_with_valid_signature.t Sequence.t]
                dropped
                (F_sequence.to_seq drop_queue) ;
              (* Add the new transaction *)
              let%bind cmd, _ =
                let%map v, dropped' =
                  add_from_gossip_exn ~config cmd current_nonce balance
                    by_sender
                in
                (* We've already removed them, so this should always be empty. *)
                assert (Sequence.is_empty dropped') ;
                (v, dropped)
              in
              let drop_head, drop_tail =
                Option.value_exn (Sequence.next dropped)
              in
              let increment =
                Option.value_exn Currency.Fee.(fee - User_command.fee to_drop)
              in
              (* Re-add all of the transactions we dropped until there are none left,
                 or until the fees from dropped transactions exceed the fee increase
                 over the first transaction.
              *)
              let%bind increment, dropped' =
                let rec go increment dropped dropped' current_nonce : _ M.t =
                  match (Sequence.next dropped, dropped') with
                  | None, Some dropped' ->
                      return (increment, dropped')
                  | None, None ->
                      return (increment, Sequence.empty)
                  | Some (cmd, dropped), Some _ -> (
                      let cmd_unchecked =
                        Transaction_hash.User_command_with_valid_signature
                        .command cmd
                      in
                      let replace_fee = User_command.fee cmd_unchecked in
                      match Currency.Fee.(increment - replace_fee) with
                      | Some increment ->
                          go increment dropped dropped' current_nonce
                      | None ->
                          Error
                            (Insufficient_replace_fee
                               (`Replace_fee replace_fee, increment) )
                          |> M.of_result )
                  | Some (cmd, dropped'), None ->
                      let current_nonce = Account_nonce.succ current_nonce in
                      let by_sender_pre = !by_sender in
                      M.catch
                        (add_from_gossip_exn ~config cmd current_nonce balance
                           by_sender ) ~f:(function
                        | Ok ((_v, dropped_), ups) ->
                            assert (Sequence.is_empty dropped_) ;
                            let%bind () = M.write_all ups in
                            go increment dropped' None current_nonce
                        | Error _err ->
                            by_sender := by_sender_pre ;
                            (* Re-evaluate with the same [dropped] to calculate the new
                               fee increment.
                            *)
                            go increment dropped (Some dropped') current_nonce )
                in
                go increment drop_tail None current_nonce
              in
              let%map () =
                Result.ok_if_true
                  Currency.Fee.(increment >= replace_fee)
                  ~error:
                    (Insufficient_replace_fee
                       (`Replace_fee replace_fee, increment) )
                |> M.of_result
                (* C3 *)
              in
              (cmd, Sequence.(append (return drop_head) dropped')) )
            else
              (*Invalid nonce or duplicate transaction got in- either way error*)
              M.of_result
                (Error
                   (Invalid_nonce
                      (`Expected queue_target_nonce, cmd_applicable_at_nonce) )
                ) )
end

module Add_from_gossip_exn0 = Add_from_gossip_exn (Writer_result)

let add_from_gossip_exn t cmd nonce balance =
  let open Result.Let_syntax in
  let%map (c, cs), t =
    run' t cmd
      (Add_from_gossip_exn0.add_from_gossip_exn ~config:t.config cmd nonce
         balance )
  in
  (c, t, cs)

(** Add back the commands that were removed due to a reorg*)
let add_from_backtrack :
       t
    -> Transaction_hash.User_command_with_valid_signature.t
    -> (t, Command_error.t) Result.t =
 fun ({ config = { constraint_constants; _ }; _ } as t) cmd ->
  let open Result.Let_syntax in
  let unchecked =
    Transaction_hash.User_command_with_valid_signature.command cmd
  in
  let%map () = check_expiry t.config unchecked in
  let fee_payer = User_command.fee_payer unchecked in
  let fee_per_wu = User_command.fee_per_wu unchecked in
  let cmd_hash = Transaction_hash.User_command_with_valid_signature.hash cmd in
  let consumed =
    Option.value_exn (currency_consumed ~constraint_constants cmd)
  in
  match Map.find t.all_by_sender fee_payer with
  | None ->
      { all_by_sender =
          (* If the command comes from backtracking, then we know it doesn't
             cause overflow, so it's OK to throw here.
          *)
          Map.add_exn t.all_by_sender ~key:fee_payer
            ~data:(F_sequence.singleton cmd, consumed)
      ; all_by_fee =
          Map_set.insert
            (module Transaction_hash.User_command_with_valid_signature)
            t.all_by_fee fee_per_wu cmd
      ; all_by_hash = Map.set t.all_by_hash ~key:cmd_hash ~data:cmd
      ; applicable_by_fee =
          Map_set.insert
            (module Transaction_hash.User_command_with_valid_signature)
            t.applicable_by_fee fee_per_wu cmd
      ; transactions_with_expiration =
          add_to_expiration t.transactions_with_expiration cmd
      ; size = t.size + 1
      ; config = t.config
      }
  | Some (queue, currency_reserved) ->
      let first_queued = F_sequence.head_exn queue in
      if
        not
          (Account_nonce.equal
             (unchecked |> User_command.expected_target_nonce)
             ( first_queued
             |> Transaction_hash.User_command_with_valid_signature.command
             |> User_command.applicable_at_nonce ) )
      then
        failwith
        @@ sprintf
             !"indexed pool nonces inconsistent when adding from backtrack. \
               Trying to add \
               %{sexp:Transaction_hash.User_command_with_valid_signature.t} to \
               %{sexp: t}"
             cmd t ;
      let t' = remove_applicable_exn t first_queued in
      { applicable_by_fee =
          Map_set.insert
            (module Transaction_hash.User_command_with_valid_signature)
            t'.applicable_by_fee fee_per_wu cmd
      ; all_by_fee =
          Map_set.insert
            (module Transaction_hash.User_command_with_valid_signature)
            t'.all_by_fee fee_per_wu cmd
      ; all_by_hash =
          Map.set t.all_by_hash
            ~key:(Transaction_hash.User_command_with_valid_signature.hash cmd)
            ~data:cmd
      ; all_by_sender =
          Map.set t'.all_by_sender ~key:fee_payer
            ~data:
              ( F_sequence.cons cmd queue
              , Option.value_exn Currency.Amount.(currency_reserved + consumed)
              )
      ; transactions_with_expiration =
          add_to_expiration t.transactions_with_expiration cmd
      ; size = t.size + 1
      ; config = t.config
      }

let global_slot_since_genesis t = global_slot_since_genesis t.config

let global_slot_since_hard_fork t = global_slot_since_hard_fork t.config
