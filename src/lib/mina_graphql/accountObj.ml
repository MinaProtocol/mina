open Core
open Graphql_async
open Mina_base
open Signature_lib
open Currency
module Schema = Graphql_wrapper.Make (Schema)
open Schema

include struct
  open Graphql_lib.Scalars

  let public_key = PublicKey.typ ()

  let uint64 = UInt64.typ ()

  let uint32 = UInt32.typ ()

  let token_id = TokenId.typ ()

  let json : (Mina_lib.t, Yojson.Basic.t option) typ = JSON.typ ()

  (* let epoch_seed = EpochSeed.typ () *)
end
module AnnotatedBalance = struct
  type t =
    { total : Balance.t
    ; unknown : Balance.t
    ; timing : Mina_base.Account_timing.t
    ; breadcrumb : Transition_frontier.Breadcrumb.t option
    }

  let min_balance (b : t) =
    match (b.timing, b.breadcrumb) with
    | Untimed, _ ->
       Some Balance.zero
    | Timed _, None ->
       None
    | Timed timing_info, Some crumb ->
       let consensus_state =
         Transition_frontier.Breadcrumb.consensus_state crumb
       in
       let global_slot =
         Consensus.Data.Consensus_state.global_slot_since_genesis
           consensus_state
       in
       Some
         (Account.min_balance_at_slot ~global_slot
            ~cliff_time:timing_info.cliff_time
            ~cliff_amount:timing_info.cliff_amount
            ~vesting_period:timing_info.vesting_period
            ~vesting_increment:timing_info.vesting_increment
            ~initial_minimum_balance:timing_info.initial_minimum_balance )

  let obj =
    obj "AnnotatedBalance"
      ~doc:
      "A total balance annotated with the amount that is currently \
       unknown with the invariant unknown <= total, as well as the \
       currently liquid and locked balances." ~fields:(fun _ ->
        [ field "total" ~typ:(non_null uint64)
            ~doc:"The amount of mina owned by the account"
            ~args:Arg.[]
            ~resolve:(fun _ (b : t) -> Balance.to_uint64 b.total)
        ; field "unknown" ~typ:(non_null uint64)
            ~doc:
            "The amount of mina owned by the account whose origin is \
             currently unknown"
            ~deprecated:(Deprecated None)
            ~args:Arg.[]
            ~resolve:(fun _ (b : t) -> Balance.to_uint64 b.unknown)
        ; field "liquid" ~typ:uint64
            ~doc:
            "The amount of mina owned by the account which is currently \
             available. Can be null if bootstrapping."
            ~deprecated:(Deprecated None)
            ~args:Arg.[]
            ~resolve:(fun _ (b : t) ->
              Option.map (min_balance b) ~f:(fun min_balance ->
                  let total_balance : uint64 = Balance.to_uint64 b.total in
                  let min_balance_uint64 = Balance.to_uint64 min_balance in
                  if
                    Unsigned.UInt64.compare total_balance min_balance_uint64
                    > 0
                  then Unsigned.UInt64.sub total_balance min_balance_uint64
                  else Unsigned.UInt64.zero ) )
        ; field "locked" ~typ:uint64
            ~doc:
            "The amount of mina owned by the account which is currently \
             locked. Can be null if bootstrapping."
            ~deprecated:(Deprecated None)
            ~args:Arg.[]
            ~resolve:(fun _ (b : t) ->
              Option.map (min_balance b) ~f:Balance.to_uint64 )
        ; field "blockHeight" ~typ:(non_null uint32)
            ~doc:"Block height at which balance was measured"
            ~args:Arg.[]
            ~resolve:(fun _ (b : t) ->
              match b.breadcrumb with
              | None ->
                 Unsigned.UInt32.zero
              | Some crumb ->
                 Transition_frontier.Breadcrumb.consensus_state crumb
                 |> Consensus.Data.Consensus_state.blockchain_length )
        (* TODO: Mutually recurse with "block" instead -- #5396 *)
        ; field "stateHash" ~typ:string
            ~doc:
            "Hash of block at which balance was measured. Can be null if \
             bootstrapping. Guaranteed to be non-null for direct account \
             lookup queries when not bootstrapping. Can also be null \
             when accessed as nested properties (eg. via delegators). "
            ~args:Arg.[]
            ~resolve:(fun _ (b : t) ->
              Option.map b.breadcrumb ~f:(fun crumb ->
                  State_hash.to_base58_check
                  @@ Transition_frontier.Breadcrumb.state_hash crumb ) )
      ] )
end

module Partial_account = struct
  let to_full_account
        { Account.Poly.public_key
        ; token_id
        ; token_permissions
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing
        ; permissions
        ; snapp
        } =
    let open Option.Let_syntax in
    let%bind public_key = public_key in
    let%bind token_permissions = token_permissions in
    let%bind nonce = nonce in
    let%bind receipt_chain_hash = receipt_chain_hash in
    let%bind delegate = delegate in
    let%bind voting_for = voting_for in
    let%bind timing = timing in
    let%bind permissions = permissions in
    let%map snapp = snapp in
    { Account.Poly.public_key
    ; token_id
    ; token_permissions
    ; nonce
    ; balance
    ; receipt_chain_hash
    ; delegate
    ; voting_for
    ; timing
    ; permissions
    ; snapp
    }

  let of_full_account ?breadcrumb
        { Account.Poly.public_key
        ; token_id
        ; token_permissions
        ; nonce
        ; balance
        ; receipt_chain_hash
        ; delegate
        ; voting_for
        ; timing
        ; permissions
        ; snapp
        } =
    { Account.Poly.public_key
    ; token_id
    ; token_permissions = Some token_permissions
    ; nonce = Some nonce
    ; balance =
        { AnnotatedBalance.total = balance
        ; unknown = balance
        ; timing
        ; breadcrumb
        }
    ; receipt_chain_hash = Some receipt_chain_hash
    ; delegate
    ; voting_for = Some voting_for
    ; timing
    ; permissions = Some permissions
    ; snapp
    }

  let of_account_id coda account_id =
    let account =
      coda |> Mina_lib.best_tip |> Participating_state.active
      |> Option.bind ~f:(fun tip ->
             let ledger =
               Transition_frontier.Breadcrumb.staged_ledger tip
               |> Staged_ledger.ledger
             in
             Ledger.location_of_account ledger account_id
             |> Option.bind ~f:(Ledger.get ledger)
             |> Option.map ~f:(fun account -> (account, tip)) )
    in
    match account with
    | Some (account, breadcrumb) ->
       of_full_account ~breadcrumb account
    | None ->
       Account.
       { Poly.public_key = Account_id.public_key account_id
       ; token_id = Account_id.token_id account_id
       ; token_permissions = None
       ; nonce = None
       ; delegate = None
       ; balance =
           { AnnotatedBalance.total = Balance.zero
           ; unknown = Balance.zero
           ; timing = Timing.Untimed
           ; breadcrumb = None
           }
       ; receipt_chain_hash = None
       ; voting_for = None
       ; timing = Timing.Untimed
       ; permissions = None
       ; snapp = None
       }

  let of_pk coda pk =
    of_account_id coda (Account_id.create pk Token_id.default)
end

type t =
  { account :
      ( Public_key.Compressed.t
      , Token_id.t
      , Token_permissions.t option
      , AnnotatedBalance.t
      , Account.Nonce.t option
      , Receipt.Chain_hash.t option
      , Public_key.Compressed.t option
      , State_hash.t option
      , Account.Timing.t
      , Permissions.t option
      , Snapp_account.t option )
        Account.Poly.t
  ; locked : bool option
  ; is_actively_staking : bool
  ; path : string
  ; index : Account.Index.t option
  }

let lift coda pk account =
  let block_production_pubkeys = Mina_lib.block_production_pubkeys coda in
  let accounts = Mina_lib.wallets coda in
  let best_tip_ledger = Mina_lib.best_ledger coda in
  { account
  ; locked = Secrets.Wallets.check_locked accounts ~needle:pk
  ; is_actively_staking =
      ( if Token_id.(equal default) account.token_id then
          Public_key.Compressed.Set.mem block_production_pubkeys pk
        else (* Non-default token accounts cannot stake. *)
          false )
  ; path = Secrets.Wallets.get_path accounts pk
  ; index =
      ( match best_tip_ledger with
        | `Active ledger ->
           Option.try_with (fun () ->
               Ledger.index_of_account_exn ledger
                 (Account_id.create account.public_key account.token_id) )
        | _ ->
           None )
  }

let get_best_ledger_account coda aid =
  lift coda
    (Account_id.public_key aid)
    (Partial_account.of_account_id coda aid)

let get_best_ledger_account_pk coda pk =
  lift coda pk (Partial_account.of_pk coda pk)

let account_id { Account.Poly.public_key; token_id; _ } =
  Account_id.create public_key token_id

let rec account =
  lazy
    (obj "Account" ~doc:"An account record according to the daemon"
       ~fields:(fun _ ->
         [ field "publicKey" ~typ:(non_null public_key)
             ~doc:"The public identity of the account"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } ->
               account.Account.Poly.public_key )
         ; field "token" ~typ:(non_null token_id)
             ~doc:"The token associated with this account"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } -> account.Account.Poly.token_id)
         ; field "timing" ~typ:(non_null @@ Mina_base_unix.Graphql_objects.account_timing ())
             ~doc:"The timing associated with this account"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } -> account.Account.Poly.timing)
         ; field "balance"
             ~typ:(non_null AnnotatedBalance.obj)
             ~doc:"The amount of mina owned by the account"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } -> account.Account.Poly.balance)
         ; field "nonce" ~typ:string
             ~doc:
             "A natural number that increases with each transaction \
              (stringified uint32)"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } ->
               Option.map ~f:Account.Nonce.to_string
                 account.Account.Poly.nonce )
         ; field "inferredNonce" ~typ:string
             ~doc:
             "Like the `nonce` field, except it includes the scheduled \
              transactions (transactions not yet included in a block) \
              (stringified uint32)"
             ~args:Arg.[]
             ~resolve:(fun { ctx = coda; _ } { account; _ } ->
               let account_id = account_id account in
               match
                 Mina_lib
                   .get_inferred_nonce_from_transaction_pool_and_ledger coda
                   account_id
               with
               | `Active (Some nonce) ->
                  Some (Account.Nonce.to_string nonce)
               | `Active None | `Bootstrapping ->
                  None )
         ; field "epochDelegateAccount" ~typ:(Lazy.force account)
             ~doc:
             "The account that you delegated on the staking ledger of \
              the current block's epoch"
             ~args:Arg.[]
             ~resolve:(fun { ctx = coda; _ } { account; _ } ->
               let open Option.Let_syntax in
               let account_id = account_id account in
               match%bind Mina_lib.staking_ledger coda with
               | Genesis_epoch_ledger staking_ledger -> (
                 match
                   let open Option.Let_syntax in
                   account_id
                   |> Ledger.location_of_account staking_ledger
                   >>= Ledger.get staking_ledger
                 with
                 | Some delegate_account ->
                    let delegate_key = delegate_account.public_key in
                    Some (get_best_ledger_account_pk coda delegate_key)
                 | None ->
                    [%log' warn (Mina_lib.top_level_logger coda)]
                      "Could not retrieve delegate account from the \
                       genesis ledger. The account was not present in \
                       the ledger." ;
                    None )
               | Ledger_db staking_ledger -> (
                 try
                   let index =
                     Mina_base.Ledger.Db.index_of_account_exn
                       staking_ledger account_id
                   in
                   let delegate_account =
                     Mina_base.Ledger.Db.get_at_index_exn staking_ledger
                       index
                   in
                   let delegate_key = delegate_account.public_key in
                   Some (get_best_ledger_account_pk coda delegate_key)
                 with e ->
                   [%log' warn (Mina_lib.top_level_logger coda)]
                     ~metadata:[ ("error", `String (Exn.to_string e)) ]
                     "Could not retrieve delegate account from sparse \
                      ledger. The account may not be in the ledger: \
                      $error" ;
                   None ) )
         ; field "receiptChainHash" ~typ:string
             ~doc:"Top hash of the receipt chain merkle-list"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } ->
               Option.map ~f:Receipt.Chain_hash.to_base58_check
                 account.Account.Poly.receipt_chain_hash )
         ; field "delegate" ~typ:public_key
             ~doc:
             "The public key to which you are delegating - if you are \
              not delegating to anybody, this would return your public \
              key"
             ~args:Arg.[]
             ~deprecated:(Deprecated (Some "use delegateAccount instead"))
             ~resolve:(fun _ { account; _ } -> account.Account.Poly.delegate)
         ; field "delegateAccount" ~typ:(Lazy.force account)
             ~doc:
             "The account to which you are delegating - if you are not \
              delegating to anybody, this would return your public key"
             ~args:Arg.[]
             ~resolve:(fun { ctx = coda; _ } { account; _ } ->
               Option.map
                 ~f:(get_best_ledger_account_pk coda)
                 account.Account.Poly.delegate )
         ; field "delegators"
             ~typ:(list @@ non_null @@ Lazy.force account)
             ~doc:
             "The list of accounts which are delegating to you (note \
              that the info is recorded in the last epoch so it might \
              not be up to date with the current account status)"
             ~args:Arg.[]
             ~resolve:(fun { ctx = coda; _ } { account; _ } ->
               let open Option.Let_syntax in
               let pk = account.Account.Poly.public_key in
               let%map delegators =
                 Mina_lib.current_epoch_delegators coda ~pk
               in
               let best_tip_ledger = Mina_lib.best_ledger coda in
               List.map
                 ~f:(fun a ->
                   { account = Partial_account.of_full_account a
                   ; locked = None
                   ; is_actively_staking = true
                   ; path = ""
                   ; index =
                       ( match best_tip_ledger with
                         | `Active ledger ->
                            Option.try_with (fun () ->
                                Ledger.index_of_account_exn ledger
                                  (Account.identifier a) )
                         | _ ->
                            None )
                 } )
                 delegators )
         ; field "lastEpochDelegators"
             ~typ:(list @@ non_null @@ Lazy.force account)
             ~doc:
             "The list of accounts which are delegating to you in the \
              last epoch (note that the info is recorded in the one \
              before last epoch epoch so it might not be up to date with \
              the current account status)"
             ~args:Arg.[]
             ~resolve:(fun { ctx = coda; _ } { account; _ } ->
               let open Option.Let_syntax in
               let pk = account.Account.Poly.public_key in
               let%map delegators =
                 Mina_lib.last_epoch_delegators coda ~pk
               in
               let best_tip_ledger = Mina_lib.best_ledger coda in
               List.map
                 ~f:(fun a ->
                   { account = Partial_account.of_full_account a
                   ; locked = None
                   ; is_actively_staking = true
                   ; path = ""
                   ; index =
                       ( match best_tip_ledger with
                         | `Active ledger ->
                            Option.try_with (fun () ->
                                Ledger.index_of_account_exn ledger
                                  (Account.identifier a) )
                         | _ ->
                            None )
                 } )
                 delegators )
         ; field "votingFor" ~typ:string
             ~doc:
             "The previous epoch lock hash of the chain which you are \
              voting for"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } ->
               Option.map ~f:Mina_base.State_hash.to_base58_check
                 account.Account.Poly.voting_for )
         ; field "stakingActive" ~typ:(non_null bool)
             ~doc:
             "True if you are actively staking with this account on the \
              current daemon - this may not yet have been updated if the \
              staking key was changed recently"
             ~args:Arg.[]
             ~resolve:(fun _ { is_actively_staking; _ } ->
               is_actively_staking )
         ; field "privateKeyPath" ~typ:(non_null string)
             ~doc:"Path of the private key file for this account"
             ~args:Arg.[]
             ~resolve:(fun _ { path; _ } -> path)
         ; field "locked" ~typ:bool
             ~doc:
             "True if locked, false if unlocked, null if the account \
              isn't tracked by the queried daemon"
             ~args:Arg.[]
             ~resolve:(fun _ { locked; _ } -> locked)
         ; field "isTokenOwner" ~typ:bool
             ~doc:"True if this account owns its associated token"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } ->
               match%map.Option account.token_permissions with
               | Token_owned _ ->
                  true
               | Not_owned _ ->
                  false )
         ; field "isDisabled" ~typ:bool
             ~doc:
             "True if this account has been disabled by the owner of the \
              associated token"
             ~args:Arg.[]
             ~resolve:(fun _ { account; _ } ->
               match%map.Option account.token_permissions with
               | Token_owned _ ->
                  false
               | Not_owned { account_disabled } ->
                  account_disabled )
         ; field "index" ~typ:int
             ~doc:
             "The index of this account in the ledger, or null if this \
              account does not yet have a known position in the best tip \
              ledger"
             ~args:Arg.[]
             ~resolve:(fun _ { index; _ } -> index)
    ] ) )

let account = Lazy.force account
