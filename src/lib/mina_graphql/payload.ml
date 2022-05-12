open Core
open Async
open Graphql_async
open Mina_base
module Ledger = Mina_ledger.Ledger

type context_typ = Mina_lib.t

module Wrapper = Graphql_utils.Wrapper.Make2 (Schema)
open Wrapper
open Graphql_lib.Base_types

let public_key = public_key ()

let peer : (context_typ, Network_peer.Peer.t option) typ =
  obj "NetworkPeerPayload" ~fields:(fun _ ->
      [ field "peerId" ~doc:"base58-encoded peer ID" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ peer -> peer.Network_peer.Peer.peer_id)
      ; field "host" ~doc:"IP address of the remote host" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ peer ->
            Unix.Inet_addr.to_string peer.Network_peer.Peer.host)
      ; field "libp2pPort" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ peer -> peer.Network_peer.Peer.libp2p_port)
      ])

let create_account : (Mina_lib.t, Account.key option) typ =
  obj "AddAccountPayload" ~fields:(fun _ ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~doc:"Public key of the created account"
          ~deprecated:(Deprecated (Some "use account field instead"))
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ; field "account"
          ~typ:(non_null Types.AccountObj.account)
          ~doc:"Details of created account"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } key ->
            Types.AccountObj.get_best_ledger_account_pk coda key)
      ])

module Unlock_account = struct
  let typ : (Mina_lib.t, Account.key option) typ =
    obj "UnlockPayload" ~fields:(fun _ ->
        [ field "publicKey" ~typ:(non_null public_key)
            ~doc:"Public key of the unlocked account"
            ~deprecated:(Deprecated (Some "use account field instead"))
            ~args:Arg.[]
            ~resolve:(fun _ -> Fn.id)
        ; field "account"
            ~typ:(non_null Types.AccountObj.account)
            ~doc:"Details of unlocked account"
            ~args:Arg.[]
            ~resolve:(fun { ctx = coda; _ } key ->
              Types.AccountObj.get_best_ledger_account_pk coda key)
        ])

  type 'a r = { public_key : 'a }

  type 'a query =
    | Empty : unit r query
    | Public_key : { s : unit r query } -> Account.key r query

  let string_of_query query =
    let rec build_fields : type a. a query -> string list = function
      | x -> (
          match x with
          | Empty ->
              []
          | Public_key { s } ->
              "publicKey" :: build_fields s )
    in
    Stdlib.String.concat " " @@ build_fields query

  let response_of_json_non_null : type a. a query -> Yojson.Basic.t -> a =
   fun query json ->
    match query with
    | Empty ->
        { public_key = () }
    | Public_key { s = _ } ->
        { public_key =
            Account.key_of_yojson_exn
              (Graphql_utils.Json.(get "publicKey" json) :> Yojson.Safe.t)
        }

  let response_of_json : type a. a query -> Yojson.Basic.t -> a option =
   fun query json ->
    match json with
    | `Null ->
        None
    | _ ->
        Some (response_of_json_non_null query json)
end

let lock_account : (Mina_lib.t, Account.key option) typ =
  obj "LockPayload" ~fields:(fun _ ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~doc:"Public key of the locked account"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ; field "account"
          ~typ:(non_null Types.AccountObj.account)
          ~doc:"Details of locked account"
          ~args:Arg.[]
          ~resolve:(fun { ctx = coda; _ } key ->
            Types.AccountObj.get_best_ledger_account_pk coda key)
      ])

let delete_account =
  obj "DeleteAccountPayload" ~fields:(fun _ ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~doc:"Public key of the deleted account"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let reload_accounts : (context_typ, _) typ =
  obj "ReloadAccountsPayload" ~fields:(fun _ ->
      [ field "success" ~typ:(non_null bool)
          ~doc:"True when the reload was successful"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let import_account =
  obj "ImportAccountPayload" ~fields:(fun _ ->
      [ field "publicKey" ~doc:"The public key of the imported account"
          ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ -> fst)
      ; field "alreadyImported"
          ~doc:"True if the account had already been imported"
          ~typ:(non_null bool)
          ~args:Arg.[]
          ~resolve:(fun _ -> snd)
      ; field "success" ~typ:(non_null bool)
          ~args:Arg.[]
          ~resolve:(fun _ _ -> true)
      ])

let string_of_banned_status = function
  | Trust_system.Banned_status.Unbanned ->
      None
  | Banned_until tm ->
      Some (Time.to_string tm)

let trust_status : (context_typ, _) typ =
  obj "TrustStatusPayload" ~fields:(fun _ ->
      let open Trust_system.Peer_status in
      [ field "ipAddr" ~typ:(non_null string) ~doc:"IP address"
          ~args:Arg.[]
          ~resolve:(fun _ (peer, _) ->
            Unix.Inet_addr.to_string peer.Network_peer.Peer.host)
      ; field "peerId" ~typ:(non_null string) ~doc:"libp2p Peer ID"
          ~args:Arg.[]
          ~resolve:(fun _ (peer, __) -> peer.Network_peer.Peer.peer_id)
      ; field "trust" ~typ:(non_null float) ~doc:"Trust score"
          ~args:Arg.[]
          ~resolve:(fun _ (_, { trust; _ }) -> trust)
      ; field "bannedStatus" ~typ:string ~doc:"Banned status"
          ~args:Arg.[]
          ~resolve:(fun _ (_, { banned; _ }) -> string_of_banned_status banned)
      ])

let send_payment =
  obj "SendPaymentPayload" ~fields:(fun _ ->
      [ field "payment"
          ~typ:(non_null Types.User_command.user_command)
          ~doc:"Payment that was sent"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let send_delegation =
  obj "SendDelegationPayload" ~fields:(fun _ ->
      [ field "delegation"
          ~typ:(non_null Types.User_command.user_command)
          ~doc:"Delegation change that was sent"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let send_zkapp =
  obj "SendZkappPayload" ~fields:(fun _ ->
      [ field "zkapp"
          ~typ:(non_null Types.Zkapp_command.zkapp_command)
          ~doc:"zkApp transaction that was sent"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let send_rosetta_transaction =
  obj "SendRosettaTransactionPayload" ~fields:(fun _ ->
      [ field "userCommand"
          ~typ:(non_null Types.User_command.user_command_interface)
          ~doc:"Command that was sent"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let export_logs : (context_typ, _) typ =
  obj "ExportLogsPayload" ~fields:(fun _ ->
      [ field "exportLogs"
          ~typ:
            (non_null
               (obj "TarFile" ~fields:(fun _ ->
                    [ field "tarfile" ~typ:(non_null string) ~args:[]
                        ~resolve:(fun _ basename -> basename)
                    ])))
          ~doc:"Tar archive containing logs"
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let add_payment_receipt =
  obj "AddPaymentReceiptPayload" ~fields:(fun _ ->
      [ field "payment"
          ~typ:(non_null Types.User_command.user_command)
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let set_coinbase_receiver =
  obj "SetCoinbaseReceiverPayload" ~fields:(fun _ ->
      [ field "lastCoinbaseReceiver"
          ~doc:
            "Returns the public key that was receiving coinbases previously, \
             or none if it was the block producer"
          ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ (last_receiver, _) -> last_receiver)
      ; field "currentCoinbaseReceiver"
          ~doc:
            "Returns the public key that will receive coinbase, or none if it \
             will be the block producer"
          ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ (_, current_receiver) -> current_receiver)
      ])

let set_snark_work_fee : (context_typ, _) typ =
  obj "SetSnarkWorkFeePayload" ~fields:(fun _ ->
      [ field "lastFee" ~doc:"Returns the last fee set to do snark work"
          ~typ:(non_null (uint64 ()))
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let set_snark_worker =
  obj "SetSnarkWorkerPayload" ~fields:(fun _ ->
      [ field "lastSnarkWorker"
          ~doc:"Returns the last public key that was designated for snark work"
          ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ -> Fn.id)
      ])

let set_connection_gating_config =
  obj "SetConnectionGatingConfigPayload" ~fields:(fun _ ->
      [ field "trustedPeers"
          ~typ:(non_null (list (non_null peer)))
          ~doc:"Peers we will always allow connections from"
          ~args:Arg.[]
          ~resolve:(fun _ config -> config.Mina_net2.trusted_peers)
      ; field "bannedPeers"
          ~typ:(non_null (list (non_null peer)))
          ~doc:
            "Peers we will never allow connections from (unless they are also \
             trusted!)"
          ~args:Arg.[]
          ~resolve:(fun _ config -> config.Mina_net2.banned_peers)
      ; field "isolate" ~typ:(non_null bool)
          ~doc:
            "If true, no connections will be allowed unless they are from a \
             trusted peer"
          ~args:Arg.[]
          ~resolve:(fun _ config -> config.Mina_net2.isolate)
      ])
