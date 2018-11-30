open Core
open Coda_base
open Operators
open Signature_lib

module type Inputs_intf = sig
  module Ledger_builder_diff : sig
    type t

    val user_commands : t -> User_command.With_valid_signature.t Sequence.t

    val creator : t -> Public_key.Compressed.t
  end

  module Consensus_state : sig
    type t

    val length : t -> Coda_numbers.Length.t
  end

  module Protocol_state : sig
    type t

    val consensus_state : t -> Consensus_state.t
  end

  module External_transition : sig
    type t

    val protocol_state : t -> Protocol_state.t

    val ledger_builder_diff : t -> Ledger_builder_diff.t
  end
end

module Make
    (Inputs : Inputs_intf
      (*
       Protocols.Coda_pow.Inputs_intf
              with type User_command.t = Coda_base.User_command.t
               and type Public_key.t = Signature_lib.Public_key.t
               and type Compressed_public_key.t = Signature_lib.Public_key.Compressed.t
               and type Protocol_state_hash.t = State_hash.t *))
    (Executor : Executor_intf.S) =
struct
  open Inputs

  module From_daemon = struct
    type t =
      {accounts_changed: Account.t list; transition: External_transition.t}
  end

  module Derived_update = struct
    type t =
      | Update_delegator of
          { public_key: Public_key.Compressed.t
          ; balance: Currency.Balance.t }
      | Nonce_changed of Account.Nonce.t

    let derive ~self {From_daemon.accounts_changed; transition= _} =
      let open Sequence in
      concat_map (of_list accounts_changed)
        ~f:(fun {public_key; balance; delegate; nonce; receipt_chain_hash= _}
           ->
          if Public_key.Compressed.equal self public_key then
            if Public_key.Compressed.equal self delegate then
              of_list
                [Update_delegator {public_key; balance}; Nonce_changed nonce]
            else singleton (Nonce_changed nonce)
          else if Public_key.Compressed.equal self delegate then
            singleton (Update_delegator {public_key; balance})
          else empty )
  end

  module Delegator = struct
    module Config = struct
      type t = {trigger: Trigger.t (* The minimum ratio of payout / fee *)}
      [@@deriving sexp]
    end

    type t =
      { confirmed_paid: Currency.Amount.t
      ; pending_paid: Currency.Amount.t
      ; amount_owed:
          Bignum.t
          (* TODO: This number should be rounded every so often to prevent memory leaks *)
      ; balance_staked: Currency.Balance.t
      ; config: Config.t }
    [@@deriving sexp]
  end

  module Config = struct
    type t =
      { public_key: Public_key.Compressed.t
      ; cut: Bignum.t
      ; max_fee: Currency.Fee.t
      ; default_payout_period: int
      ; min_payout: Currency.Amount.t }
    [@@deriving sexp]
  end

  type t =
    { delegators: Delegator.t Public_key.Compressed.Table.t
    ; mutable total_stake: Currency.Amount.t
    ; mutable total_reward: Currency.Amount.t
    ; executor: Executor.t
    ; logger: Logger.t sexp_opaque
    ; config: Config.t }
  [@@deriving sexp]

  let default_config t current_block =
    { Delegator.Config.trigger=
        Every_n_blocks {n= t.config.default_payout_period; prev= current_block}
    }

  let add_delegate current_block t public_key balance =
    t.total_stake <- t.total_stake +! Currency.Balance.to_amount balance ;
    Hashtbl.set t.delegators ~key:public_key
      ~data:
        { confirmed_paid= Currency.Amount.zero
        ; amount_owed= Bignum.zero
        ; pending_paid= Currency.Amount.zero
        ; balance_staked= balance
        ; config= default_config t current_block }

  let create ~current_nonce ~current_block ~delegators ~logger ~config
      ~broadcast_user_command =
    let t =
      { delegators= Public_key.Compressed.Table.create ()
      ; total_stake= Currency.Amount.zero
      ; total_reward= Currency.Amount.zero
      ; logger
      ; config
      ; executor=
          Executor.create ~account_nonce:current_nonce
            ~broadcast:broadcast_user_command ~fee:config.Config.max_fee }
    in
    List.iter delegators ~f:(fun (a : Account.t) ->
        add_delegate current_block t a.public_key a.balance ) ;
    t

  let self t = t.config.public_key

  let log_error t fmt = Logger.error t.logger fmt

  (* TODO: This stinks *)
  let bignum_of_amount = Fn.compose Bignum.of_string Currency.Amount.to_string

  let bignum_of_balance =
    Fn.compose Bignum.of_string Currency.Balance.to_string

  let amount_of_bigint n = Bigint.to_string n |> Currency.Amount.of_string

  let current_block transition =
    External_transition.protocol_state transition
    |> Protocol_state.consensus_state |> Consensus_state.length

  let triggered (transition : External_transition.t)
      ~(global_config : Config.t) ~payout_amount
      ~(delegator_config : Delegator.Config.t) =
    Currency.Amount.(payout_amount > global_config.min_payout)
    &&
    match delegator_config.trigger with
    | Never -> false
    | Every_n_blocks {n; prev} ->
        Int.(
          Coda_numbers.Length.to_int (current_block transition)
          >= n + Coda_numbers.Length.to_int prev)

  let distribute_reward ~executor ~reward_to_distribute ~total_stake
      ~transition ~public_key (s : Delegator.t) ~config =
    let reward =
      Bignum.(
        reward_to_distribute * bignum_of_balance s.balance_staked / total_stake)
    in
    let amount_owed' = Bignum.(s.amount_owed + reward) in
    let to_add_to_pending =
      amount_of_bigint (Bignum.round_as_bigint_exn ~dir:`Down amount_owed')
    in
    if
      triggered ~payout_amount:to_add_to_pending ~delegator_config:s.config
        ~global_config:config transition
    then (
      Executor.payout executor ~receiver:public_key ~amount:to_add_to_pending ;
      { s with
        pending_paid= s.pending_paid +! to_add_to_pending
      ; amount_owed= Bignum.(amount_owed' - bignum_of_amount to_add_to_pending)
      } )
    else {s with amount_owed= amount_owed'}

  let on_long_tip_transition t (transiton : From_daemon.t) =
    match
      List.find_map transiton.accounts_changed ~f:(fun a ->
          if Public_key.Compressed.equal a.public_key t.config.public_key then
            Some a.nonce
          else None )
    with
    | None -> ()
    | Some n ->
        Executor.long_tip_confirm t.executor ~account_nonce:n
          ~length:(current_block transiton.transition)

  let on_locked_tip_transition t (transition : From_daemon.t) =
    let update_delegator public_key balance =
      match Hashtbl.find t.delegators public_key with
      | None ->
          add_delegate
            (current_block transition.transition)
            t public_key balance
      | Some s ->
          t.total_stake
          <- t.total_stake
             -! Currency.Balance.to_amount s.balance_staked
             +! Currency.Balance.to_amount balance ;
          Hashtbl.set t.delegators ~key:public_key
            ~data:{s with balance_staked= balance}
    in
    let diff = External_transition.ledger_builder_diff transition.transition in
    if Public_key.Compressed.equal (self t) (Ledger_builder_diff.creator diff)
    then (
      let reward = Protocols.Coda_praos.coinbase_amount in
      let reward_to_distribute =
        Bignum.(bignum_of_amount reward * (one - t.config.cut))
      in
      t.total_reward <- t.total_reward +! reward ;
      let total_stake = bignum_of_amount t.total_stake in
      Hashtbl.mapi_inplace t.delegators ~f:(fun ~key ~data ->
          distribute_reward data ~executor:t.executor ~reward_to_distribute
            ~config:t.config ~total_stake ~transition:transition.transition
            ~public_key:key ) ) ;
    Sequence.iter
      (Derived_update.derive transition ~self:(self t))
      ~f:(fun u ->
        match u with
        | Nonce_changed account_nonce ->
            Hashtbl.merge_into
              ~src:(Executor.locked_tip_confirm t.executor ~account_nonce)
              ~dst:t.delegators ~f:(fun ~key:receiver confirmed_amount s ->
                match s with
                | None ->
                    log_error t
                      !"Could not find recipient of payment \
                        %{sexp:Public_key.Compressed.t}"
                      receiver ;
                    Remove
                | Some data ->
                    Set_to
                      { data with
                        confirmed_paid= data.confirmed_paid +! confirmed_amount
                      ; pending_paid= data.pending_paid -! confirmed_amount }
            )
        | Update_delegator {public_key; balance} ->
            update_delegator public_key balance )
end

let%test_module "stake pool test" =
  ( module struct
    module Inputs = struct
      module Ledger_builder_diff = struct
        type t =
          { creator: Public_key.Compressed.t
          ; user_commands: User_command.With_valid_signature.t Sequence.t }
        [@@deriving fields]
      end

      module Consensus_state = struct
        type t = Coda_numbers.Length.t

        let length = Fn.id
      end

      module Protocol_state = struct
        type t = Consensus_state.t

        let consensus_state = Fn.id
      end

      module External_transition = struct
        type t =
          { protocol_state: Protocol_state.t
          ; ledger_builder_diff: Ledger_builder_diff.t }
        [@@deriving fields]
      end
    end

    open Async
    include Make (Inputs) (Executor)

    let self_kp = Genesis_ledger.largest_account_keypair_exn ()

    let self = Public_key.compress self_kp.public_key

    let other = (snd (List.nth_exn Genesis_ledger.accounts 5)).public_key

    let ledger = Ledger.copy Genesis_ledger.t

    let blocks_won = 0.5

    let delegators =
      let delegators =
        Int.of_float (blocks_won *. Int.to_float (Ledger.num_accounts ledger))
      in
      let to_set, _ =
        Ledger.foldi ledger ~init:([], 0) ~f:(fun _addr (acc, i) a ->
            if i < delegators && Currency.Balance.(a.balance <= of_int 2000)
            then
              ( ( Option.value_exn (Ledger.location_of_key ledger a.public_key)
                , {a with delegate= self} )
                :: acc
              , i + 1 )
            else (acc, i) )
      in
      List.map to_set ~f:(fun (loc, a) -> Ledger.set ledger loc a ; a)

    open Pipe_lib
    open Inputs

    module Network = struct
      let commands_per_block = 20

      let creator () = if Random.float 1. < blocks_won then self else other

      let run ~ticks ~commands ~blocks =
        let length = ref Coda_numbers.Length.zero in
        let rec go () =
          let propose_and_loop user_commands =
            let t : External_transition.t =
              { ledger_builder_diff= {creator= creator (); user_commands}
              ; protocol_state= !length }
            in
            length := Coda_numbers.Length.succ !length ;
            let%bind () = Linear_pipe.write blocks t in
            go ()
          in
          match%bind Linear_pipe.read ticks with
          | `Eof -> Linear_pipe.close blocks ; Deferred.unit
          | `Ok () -> (
            match
              Linear_pipe.read_now' commands
                ~max_queue_length:commands_per_block
            with
            | `Eof -> Deferred.unit
            | `Nothing_available -> propose_and_loop Sequence.empty
            | `Ok q -> propose_and_loop (Sequence.of_list (Queue.to_list q)) )
        in
        go ()
    end

    let delay pipe n =
      let q = Queue.create () in
      Linear_pipe.filter_map pipe ~f:(fun x ->
          Queue.enqueue q x ;
          if Queue.length q > n then Some (Queue.dequeue_exn q) else None )

    let lock_length = 3

    let sum zero add get t =
      Hashtbl.fold t.delegators ~init:zero ~f:(fun ~key:_ ~data acc ->
          add acc (get data) )

    let amount_owed = sum Bignum.zero Bignum.( + ) (fun d -> d.amount_owed)

    let confirmed_paid =
      sum Currency.Amount.zero ( +! ) (fun d -> d.confirmed_paid)

    let pending_paid = sum Currency.Amount.zero ( +! ) (fun d -> d.pending_paid)

    let%test_unit "main" =
      let blocks_reader, blocks_writer = Linear_pipe.create () in
      let from_daemon =
        Linear_pipe.map blocks_reader ~f:(fun (t : External_transition.t) ->
            let accounts_changed =
              Sequence.fold ~init:Public_key.Compressed.Map.empty
                t.ledger_builder_diff.user_commands ~f:(fun acc c ->
                  Or_error.ok_exn (Ledger.apply_user_command ledger c)
                  |> ignore ;
                  List.fold
                    (User_command.accounts_accessed (c :> User_command.t))
                    ~init:acc
                    ~f:(fun acc k ->
                      let a =
                        Option.value_exn
                          (Ledger.get ledger
                             (Option.value_exn
                                (Ledger.location_of_key ledger k)))
                      in
                      Map.set acc ~key:k ~data:a ) )
            in
            { From_daemon.accounts_changed= Map.data accounts_changed
            ; transition= t } )
      in
      let long_tip, locked_tip =
        let r1, r2 = Linear_pipe.fork2 from_daemon in
        (r1, delay r2 lock_length)
      in
      let command_reader, command_writer = Linear_pipe.create () in
      let ticks =
        Linear_pipe.of_list (List.init (lock_length + 2000) ~f:ignore)
      in
      let t =
        create ~current_nonce:Account.Nonce.zero
          ~current_block:Coda_numbers.Length.zero ~logger:(Logger.create ())
          ~delegators
          ~config:
            { Config.public_key= self
            ; min_payout= Currency.Amount.of_int 1
            ; default_payout_period= 2
            ; cut= Bignum.(one / of_int 2)
            ; max_fee= Currency.Fee.of_int 1 }
          ~broadcast_user_command:(fun c ->
            Pipe.write_without_pushback command_writer
              (User_command.sign self_kp c) )
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          don't_wait_for
            (Linear_pipe.iter long_tip ~f:(fun u ->
                 return (on_long_tip_transition t u) )) ;
          don't_wait_for
            (Linear_pipe.iter locked_tip ~f:(fun u ->
                 return (on_locked_tip_transition t u) )) ;
          let%bind () =
            Network.run ~ticks ~commands:command_reader ~blocks:blocks_writer
          in
          let%map () = Async.after (sec 2.) in
          let expected_payout =
            Bignum.((one - t.config.cut) * bignum_of_amount t.total_reward)
          in
          [%test_eq: Bignum.t]
            Bignum.(
              bignum_of_amount (confirmed_paid t)
              + bignum_of_amount (pending_paid t)
              + amount_owed t)
            expected_payout ;
          assert (Bignum.(amount_owed t / expected_payout < one / of_int 100))
      )
  end )
