open Core
open Async
open Signature_lib
open Coda_base

module type Account_history_db_intf = sig
  type t

  val t : t
end

module Trigger = struct
  type t =
    | Every_n_blocks of { n : int; prev : Coda_numbers.Length.t }
    | Never
end

(* The goal of the executor is to get a sequence of transactions executed.
   To do so, it may need to periodically bump the fee.

   t1, t2, ..., tn
*)

module Account_state = struct
  type t =
    { receipt_chain_hash : Receipt.Chain_hash.t
    ; nonce : Account.Nonce.t
    }
end

module Payout = struct
  module T = struct
    type t =
      { receiver: Public_key.Compressed.t
      ; amount : Currency.Amount.t
      ; fee: Currency.Fee.t
      ; memo : User_command_memo.t
      ; nonce : Account.Nonce.t
      }
    [@@deriving eq, hash, compare, sexp]
  end
  include T
  include Hashable.Make(T)

  let reward { amount; fee; _ } = Currency.Amount.add_fee amount fee |> Option.value_exn
end

module Transaction_id = struct
  include Uuid

  let to_memo = Fn.compose User_command_memo.create_exn to_string
end

module type Executor_intf = sig
  type t

  val create
    :  account_nonce:Account.Nonce.t
    -> broadcast:(User_command.Payload.t -> unit)
    -> t

  val payout
    : t
    -> receiver:Public_key.Compressed.t
    -> amount:Currency.Amount.t
    -> unit

  val long_tip_confirm
    : t
    -> account_nonce:Account.Nonce.t
    -> length:Coda_numbers.Length.t
    -> unit

  val locked_tip_confirm
    : t
    -> account_nonce:Account.Nonce.t
    -> Currency.Amount.t Public_key.Compressed.Table.t
end

(* The pool manager tells the executor what delta it would like to achieve.

   I.e., the executor retains a desired payout set

   { (pk_i, amt_i)  : i in [n] }

   and tries to get all those amounts to 0. *)

  let (-!) x y = Option.value_exn (Currency.Amount.sub x y )
  let (+!) x y = Option.value_exn (Currency.Amount.add x y )

module Executor = struct
  module type Inputs_intf = sig

    val initial_receipt_chain_hash : Public_key.Compressed.t -> Receipt.Chain_hash.t Deferred.t

    val submit
      : prev:Receipt.Chain_hash.t
      -> sender:Public_key.t
      -> User_command.Payload.t
      -> Receipt.Chain_hash.t Deferred.t
  end
  module Make (Inputs : Inputs_intf) : Executor_intf = struct
    open Inputs

    module Pending_payout = struct
      type t =
        { receiver : Public_key.Compressed.t
        ; amount   : Currency.Amount.t
        ; nonce    : Account.Nonce.t
        }
    end

    type t =
      { progress : Coda_numbers.Length.t Account.Nonce.Table.t
      ; payouts : Pending_payout.t Queue.t
      ; mutable next_nonce : Account.Nonce.t
      ; broadcast : User_command_payload.t -> unit
      }

    let create ~account_nonce ~broadcast =
      { progress = Account.Nonce.Table.create ()
      ; payouts = Queue.create ()
      ; next_nonce = account_nonce
      ; broadcast
      }

    let long_tip_confirm t ~account_nonce ~length =
      Hashtbl.update t.progress account_nonce ~f:(function
        | None -> length
        | Some l -> Coda_numbers.Length.max l length)

    let dequeue_if q ~f =
      let open Option.Let_syntax in
      let%bind x = Queue.peek q in
      if f x
      then Some (Queue.dequeue_exn q)
      else None

    let (+~) x y = Option.value_exn (Currency.Amount.Signed.add x y)

    let add_opt f x =
      Option.value_map ~default:x ~f:(f x)

    let locked_tip_confirm t ~account_nonce =
      Hashtbl.filter_keys_inplace t.progress ~f:(fun n ->
        Account.Nonce.(n >= account_nonce));
      let res = Public_key.Compressed.Table.create () in
      let rec clear_payouts () =
        match dequeue_if t.payouts ~f:(fun p -> Account.Nonce.(p.nonce < account_nonce)) with
        | None -> ()
        | Some { receiver; amount; nonce = _ } ->
          Hashtbl.update res receiver ~f:(add_opt (+!) amount);
          clear_payouts ()
      in
      clear_payouts ();
      res
    ;;

    let payout t ~receiver ~amount =
      let nonce = t.next_nonce in
      Queue.enqueue t.payouts { receiver; amount; nonce };
    ;;
  end
end

module UInt64 = struct
  include Unsigned.UInt64
  include Sexpable.Of_stringable(Unsigned.UInt64)
  include Infix
  let (>=) x y = compare x y >= 0
end

module Delegator = struct
  module Config = struct
    type t =
      { trigger : Trigger.t
      (* The minimum ratio of payout / fee *)
      }
  end

  type t =
    { confirmed_paid : Currency.Amount.t
    ; pending_paid : Currency.Amount.t
    ; amount_owed : Bignum.t
    ; balance_staked : Currency.Balance.t
    ; config : Config.t
    }
end

module Make
    (Inputs : Protocols.Coda_pow.Inputs_intf
     with type User_command.t = Coda_base.User_command.t
      and type Public_key.t = Public_key.t
      and type Compressed_public_key.t = Public_key.Compressed.t
      and type Protocol_state_hash.t = State_hash.t
    )
    (Executor : Executor_intf) = struct
  open Inputs

  module From_daemon = struct
    type t =
      { accounts_changed : Account.t list
      ; transition : Consensus_mechanism.External_transition.t
      }
  end

  module Derived_update = struct
    type t =
      | Update_delegator of { public_key : Public_key.Compressed.t; balance : Currency.Balance.t }
      | Nonce_changed of Account.Nonce.t

    let user_commands (diff : Ledger_builder_diff.t) =
      match diff.pre_diffs with
      | Either.First {diff; _} -> Sequence.of_list diff.user_commands
      | Either.Second (t1, t2) ->
        Sequence.(append (of_list t1.diff.user_commands) (of_list t2.diff.user_commands))

    let derive ~self { From_daemon.accounts_changed; transition=_ } =
      let open Sequence in
      concat_map (of_list accounts_changed) ~f:(fun { public_key ; balance; delegate ; nonce; receipt_chain_hash=_ } ->
        if Public_key.Compressed.equal self public_key
        then begin 
          if Public_key.Compressed.equal self delegate
          then of_list [ Update_delegator {public_key; balance}; Nonce_changed nonce ]
          else singleton (Nonce_changed nonce)
        end else
          if Public_key.Compressed.equal self delegate
          then singleton (Update_delegator {public_key; balance})
          else empty)
  end

  module Config = struct
    type t =
      { public_key: Public_key.Compressed.t
      ; cut : Bignum.t
      ; max_fee : Currency.Fee.t
      }
    [@@deriving sexp]
  end

  type t =
    { delegtators : Delegator.t Public_key.Compressed.Table.t
    ; mutable total_stake : Currency.Amount.t
    ; executor : Executor.t
    ; memo : User_command_memo.t
    ; logger : Logger.t
    ; config : Config.t
    }

  let self t = t.config.public_key

  let log_error t fmt =
    Logger.error t.logger fmt

  let default_config _t current_block =
    { Delegator.Config.trigger = Every_n_blocks { n = 10; prev = current_block }
    }

  let add_delegate current_block t public_key balance =
    Hashtbl.set t.delegtators ~key:public_key
      ~data:
        { confirmed_paid = Currency.Amount.zero
        ; amount_owed = Bignum.zero
        ; pending_paid = Currency.Amount.zero
        ; balance_staked = balance
        ; config = default_config t current_block
        }

  (* TODO: This stinks *)
  let bignum_of_amount = Fn.compose Bignum.of_string Currency.Amount.to_string
  let bignum_of_balance = Fn.compose Bignum.of_string Currency.Balance.to_string
  let amount_of_bigint n =
    Bigint.to_string n
    |> Currency.Amount.of_string

  let current_block transition =
    let open Consensus_mechanism in
    External_transition.protocol_state transition
    |> Protocol_state.consensus_state
    |> Consensus_state.length

  let triggered 
        (transition : Consensus_mechanism.External_transition.t)
        ~payout_amount
        ~(delegator_config : Delegator.Config.t)
    =
    match delegator_config.trigger with
    | Never -> false
    | Every_n_blocks { n ; prev } ->
      let open Consensus_mechanism in
      Int.equal (n + Coda_numbers.Length.to_int prev)
        (Coda_numbers.Length.to_int (current_block transition))

  let on_locked_tip_transition t (transition : From_daemon.t) =
    let diff = Consensus_mechanism.External_transition.ledger_builder_diff transition.transition in
    if Public_key.Compressed.equal (self t) diff.creator
    then begin
      let reward_to_distribute = 
        Bignum.(bignum_of_amount Protocols.Coda_praos.coinbase_amount * (one - t.config.cut))
      in
      let changes = 
        let total_stake = bignum_of_amount t.total_stake in
        Hashtbl.fold t.delegtators ~init:[] ~f:(fun ~key ~data acc ->
          let reward =
            Bignum.(reward_to_distribute * bignum_of_balance data.balance_staked / total_stake)
          in
          let data' =
            let amount_owed = Bignum.(data.amount_owed + reward) in
            let to_add_to_pending =
              amount_of_bigint (Bignum.round_as_bigint_exn ~dir:`Down amount_owed)
              -! data.pending_paid
            in
            if triggered
                 ~payout_amount:to_add_to_pending
                 ~delegator_config:data.config
                transition.transition then begin
              Executor.payout t.executor ~receiver:key ~amount:to_add_to_pending;
              { data with
                pending_paid = data.pending_paid +! to_add_to_pending
              ; amount_owed }
            end else
              { data with amount_owed }
          in
          (key, data') :: acc)
      in
      List.iter changes ~f:(fun (key, data) -> Hashtbl.set t.delegtators ~key ~data)
    end;
    let update_delegator public_key balance =
      match Hashtbl.find t.delegtators public_key with
      | None -> add_delegate (current_block transition.transition) t public_key balance
      | Some s ->
        t.total_stake <-
          (t.total_stake -! Currency.Balance.to_amount s.balance_staked)
          +! Currency.Balance.to_amount balance;
        Hashtbl.set t.delegtators ~key:public_key ~data:{ s with balance_staked = balance }
    in
    Sequence.iter (Derived_update.derive transition ~self:(self t)) ~f:(fun u ->
      match u with
      | Nonce_changed account_nonce ->
        Hashtbl.merge_into
          ~src:(Executor.locked_tip_confirm t.executor ~account_nonce)
          ~dst:t.delegtators
          ~f:(fun ~key:receiver confirmed_amount s ->
            match s with
            | None ->
              log_error t !"Could not find recipient of payment %{sexp:Public_key.Compressed.t}"
                receiver;
              Remove
            | Some data ->
              Set_to 
                { data with
                  confirmed_paid = data.confirmed_paid +! confirmed_amount 
                ; pending_paid = data.pending_paid -! confirmed_amount
                })

      | Update_delegator { public_key; balance } ->
        update_delegator public_key balance)
end
