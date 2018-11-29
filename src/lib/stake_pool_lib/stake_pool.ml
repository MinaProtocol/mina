open Core
open Coda_base
open Operators

module Make
    (Inputs : Protocols.Coda_pow.Inputs_intf
              with type User_command.t = Coda_base.User_command.t
               and type Public_key.t = Signature_lib.Public_key.t
               and type Compressed_public_key.t = Signature_lib.Public_key.Compressed.t
               and type Protocol_state_hash.t = State_hash.t)
    (Executor : Executor_intf.S) =
struct
  open Inputs
  module Public_key = Signature_lib.Public_key

  module From_daemon = struct
    type t =
      { accounts_changed: Account.t list
      ; transition: Consensus_mechanism.External_transition.t }
  end

  module Derived_update = struct
    type t =
      | Update_delegator of
          { public_key: Public_key.Compressed.t
          ; balance: Currency.Balance.t }
      | Nonce_changed of Account.Nonce.t

    let user_commands (diff : Ledger_builder_diff.t) =
      match diff.pre_diffs with
      | Either.First {diff; _} -> Sequence.of_list diff.user_commands
      | Either.Second (t1, t2) ->
          Sequence.(
            append
              (of_list t1.diff.user_commands)
              (of_list t2.diff.user_commands))

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
    end

    type t =
      { confirmed_paid: Currency.Amount.t
      ; pending_paid: Currency.Amount.t
      ; amount_owed: Bignum.t
      ; balance_staked: Currency.Balance.t
      ; config: Config.t }
  end

  module Config = struct
    type t =
      { public_key: Public_key.Compressed.t
      ; cut: Bignum.t
      ; max_fee: Currency.Fee.t }
    [@@deriving sexp]
  end

  type t =
    { delegtators: Delegator.t Public_key.Compressed.Table.t
    ; mutable total_stake: Currency.Amount.t
    ; executor: Executor.t
    ; logger: Logger.t
    ; config: Config.t }

  let self t = t.config.public_key

  let log_error t fmt = Logger.error t.logger fmt

  let default_config _t current_block =
    {Delegator.Config.trigger= Every_n_blocks {n= 10; prev= current_block}}

  let add_delegate current_block t public_key balance =
    Hashtbl.set t.delegtators ~key:public_key
      ~data:
        { confirmed_paid= Currency.Amount.zero
        ; amount_owed= Bignum.zero
        ; pending_paid= Currency.Amount.zero
        ; balance_staked= balance
        ; config= default_config t current_block }

  (* TODO: This stinks *)
  let bignum_of_amount = Fn.compose Bignum.of_string Currency.Amount.to_string

  let bignum_of_balance =
    Fn.compose Bignum.of_string Currency.Balance.to_string

  let amount_of_bigint n = Bigint.to_string n |> Currency.Amount.of_string

  let current_block transition =
    let open Consensus_mechanism in
    External_transition.protocol_state transition
    |> Protocol_state.consensus_state |> Consensus_state.length

  let triggered (transition : Consensus_mechanism.External_transition.t)
      ~payout_amount:_ ~(delegator_config : Delegator.Config.t) =
    match delegator_config.trigger with
    | Never -> false
    | Every_n_blocks {n; prev} ->
        Int.equal
          (n + Coda_numbers.Length.to_int prev)
          (Coda_numbers.Length.to_int (current_block transition))

  let distribute_reward ~executor ~reward_to_distribute ~total_stake
      ~transition ~public_key (s : Delegator.t) =
    let reward =
      Bignum.(
        reward_to_distribute * bignum_of_balance s.balance_staked / total_stake)
    in
    let amount_owed = Bignum.(s.amount_owed + reward) in
    let to_add_to_pending =
      amount_of_bigint (Bignum.round_as_bigint_exn ~dir:`Down amount_owed)
      -! s.pending_paid
    in
    if
      triggered ~payout_amount:to_add_to_pending ~delegator_config:s.config
        transition
    then (
      Executor.payout executor ~receiver:public_key ~amount:to_add_to_pending ;
      {s with pending_paid= s.pending_paid +! to_add_to_pending; amount_owed} )
    else {s with amount_owed}

  let on_locked_tip_transition t (transition : From_daemon.t) =
    let update_delegator public_key balance =
      match Hashtbl.find t.delegtators public_key with
      | None ->
          add_delegate
            (current_block transition.transition)
            t public_key balance
      | Some s ->
          t.total_stake
          <- t.total_stake
             -! Currency.Balance.to_amount s.balance_staked
             +! Currency.Balance.to_amount balance ;
          Hashtbl.set t.delegtators ~key:public_key
            ~data:{s with balance_staked= balance}
    in
    let diff =
      Consensus_mechanism.External_transition.ledger_builder_diff
        transition.transition
    in
    ( if Public_key.Compressed.equal (self t) diff.creator then
      let reward_to_distribute =
        Bignum.(
          bignum_of_amount Protocols.Coda_praos.coinbase_amount
          * (one - t.config.cut))
      in
      let total_stake = bignum_of_amount t.total_stake in
      Hashtbl.mapi_inplace t.delegtators ~f:(fun ~key ~data ->
          distribute_reward data ~executor:t.executor ~reward_to_distribute
            ~total_stake ~transition:transition.transition ~public_key:key ) ) ;
    Sequence.iter
      (Derived_update.derive transition ~self:(self t))
      ~f:(fun u ->
        match u with
        | Nonce_changed account_nonce ->
            Hashtbl.merge_into
              ~src:(Executor.locked_tip_confirm t.executor ~account_nonce)
              ~dst:t.delegtators ~f:(fun ~key:receiver confirmed_amount s ->
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
