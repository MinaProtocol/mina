open Core
open Async
open Signature_lib
open Unsigned
open Mina_base
open Mina_graphql_client

let gen_keys count =
  Quickcheck.random_value ~seed:`Nondeterministic
    (Quickcheck.Generator.list_with_length count Public_key.Compressed.gen)

let output_keys =
  let open Command.Let_syntax in
  Command.basic ~summary:"Generate the given number of public keys on stdout"
    (let%map_open count =
       flag "--count" ~aliases:[ "count" ] ~doc:"NUM Number of keys to generate"
         (required int)
     in
     fun () ->
       List.iter (gen_keys count) ~f:(fun pk ->
           Format.printf "%s@." (Public_key.Compressed.to_base58_check pk) ) )

let output_cmds =
  let open Command.Let_syntax in
  Command.basic ~summary:"Generate the given number of public keys on stdout"
    (let%map_open count =
       flag "--count" ~aliases:[ "count" ] ~doc:"NUM Number of keys to generate"
         (required int)
     and txns_per_block =
       flag "--txn-capacity-per-block"
         ~aliases:[ "txn-capacity-per-block" ]
         ~doc:
           "NUM Transaction capacity per block. Used for rate limiting. \
            (default: 128)"
         (optional_with_default 128 int)
     and slot_time =
       flag "--slot-time" ~aliases:[ "slot-time" ]
         ~doc:
           "NUM_MILLISECONDS Slot duration in milliseconds. (default: 180000)"
         (optional_with_default 180000 int)
     and fill_rate =
       flag "--fill-rate" ~aliases:[ "fill-rate" ]
         ~doc:"FILL_RATE Fill rate (default: 0.75)"
         (optional_with_default 0.75 float)
     and rate_limit =
       flag "--apply-rate-limit" ~aliases:[ "apply-rate-limit" ]
         ~doc:
           "TRUE/FALSE Whether to emit sleep commands between commands to \
            enforce sleeps (default: true)"
         (optional_with_default true bool)
     and rate_limit_level =
       flag "--rate-limit-level" ~aliases:[ "rate-limit-level" ]
         ~doc:
           "NUM Number of transactions that can be sent in a time interval \
            before hitting the rate limit (default: 200)"
         (optional_with_default 200 int)
     and rate_limit_interval =
       flag "--rate-limit-interval" ~aliases:[ "rate-limit-interval" ]
         ~doc:
           "NUM_MILLISECONDS Interval that the rate-limiter is applied over \
            (default: 300000)"
         (optional_with_default 300000 int)
     and sender_key =
       flag "--sender-pk" ~aliases:[ "sender-pk" ]
         ~doc:"PUBLIC_KEY Public key to send the transactions from"
         (required string)
     in
     fun () ->
       let rate_limit =
         if rate_limit then
           let slot_limit =
             Float.(
               of_int txns_per_block /. of_int slot_time *. fill_rate
               *. of_int rate_limit_interval)
           in
           let limit = min (Float.to_int slot_limit) rate_limit_level in
           Some limit
         else None
       in
       let batch_count = ref 0 in
       List.iter (gen_keys count) ~f:(fun pk ->
           Option.iter rate_limit ~f:(fun rate_limit ->
               if !batch_count >= rate_limit then (
                 Format.printf "sleep %f@."
                   Float.(of_int rate_limit_interval /. 1000.) ;
                 batch_count := 0 )
               else incr batch_count ) ;
           Format.printf
             "mina client send-payment --amount 1 --receiver %s --sender %s@."
             (Public_key.Compressed.to_base58_check pk)
             sender_key ) )

let pub_key_to_string pub_key =
  pub_key |> Public_key.compress |> Public_key.Compressed.to_base58_check

let ingress_uri ~graphql_target_node =
  let target = Str.split (Str.regexp ":") graphql_target_node in
  let host =
    match List.nth target 0 with Some data -> data | None -> "127.0.0.1"
  in
  let port =
    match List.nth target 1 with
    | Some data ->
        int_of_string data
    | None ->
        3085
  in
  let path = "/graphql" in
  Uri.make ~scheme:"http" ~host ~path ~port ()

(* helper function that uses graphql command to get the nonce of a node*)
let get_nonce ~logger ~(ingress_uri : Uri.t) ~(pub_key : Account.key) =
  [%log info] "txn burst tool: Getting account balance and nonce"
    ~metadata:
      [ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pub_key)
      ; ("ingress_uri", `String (Uri.to_string ingress_uri))
      ] ;
  let account_id = Account_id.create pub_key Mina_base.Token_id.default in
  let%bind nonce =
    let%bind querry_result =
      Client.get_account_data ingress_uri ~logger ~account_id
    in
    match querry_result with
    | Ok res ->
        (* Prefer the nonce inferred from the transaction pool, so that we
           build on any of our commands that are already pending. *)
        return (Option.value res.inferred_nonce ~default:res.nonce)
    | Error _ ->
        [%log error] "txn burst tool: could not get nonce of pk"
          ~metadata:
            [ ("pub_key", Signature_lib.Public_key.Compressed.to_yojson pub_key)
            ; ("ingress_uri", `String (Uri.to_string ingress_uri))
            ] ;
        exit 1
  in
  [%log info] "txn burst tool: nonce obtained, nonce= %d" (UInt32.to_int nonce) ;
  return nonce

(* helper function for getting a keypair from a local path *)
let get_keypair ~logger path pw_option =
  let%bind keypair =
    match pw_option with
    | Some s ->
        Secrets.Keypair.read_exn ~privkey_path:path
          ~password:(s |> Bytes.of_string |> Deferred.return |> Lazy.return)
    | None ->
        Secrets.Keypair.read_exn' path
  in
  [%log info] "txn burst tool: successfully got keypair.  pub_key= %s "
    (pub_key_to_string keypair.public_key) ;
  return keypair

let there_and_back_again ~num_txn_per_acct ~txns_per_block ~slot_time ~fill_rate
    ~txn_fee_option ~rate_limit ~rate_limit_level ~rate_limit_interval
    ~pool_backpressure ~pool_high_watermark ~pool_low_watermark
    ~pool_poll_interval ~retry_delay ~max_consecutive_failures
    ~origin_sender_secret_key_path
    ~(origin_sender_secret_key_pw_option : string option)
    ~returner_secret_key_path ~(returner_secret_key_pw_option : string option)
    ~graphql_target_node_option ~minimum_user_command_fee ~signature_kind () =
  let open Deferred.Let_syntax in
  (* define the rate limiting function *)
  let open Logger in
  let logger = Logger.create () in
  let limit_level =
    let slot_limit =
      Float.(
        of_int txns_per_block /. of_int slot_time *. fill_rate
        *. of_int rate_limit_interval)
    in
    min (Float.to_int slot_limit) rate_limit_level
  in
  let batch_count = ref 0 in
  let limit =
    (* call this function after a transaction happens *)
    (* TODO: in the current state of things, this function counts to limit_level of transactions, and then slaps a pause after it.  This happens even if the transactions themselves took far longer than the pause.  It thereby makes the rate slower and more conservative than would appear.  In future, perhaps implement with some sort of Timer *)
    if rate_limit then ( fun () ->
      incr batch_count ;
      if !batch_count >= limit_level then
        let%bind () =
          Deferred.return
            ([%log info]
               "txn burst tool: rate limiting, pausing for %d milliseconds... "
               rate_limit_interval
               ~metadata:
                 [ ( "rate_limit_interval"
                   , rate_limit_interval |> Int.to_string
                     |> Yojson.Safe.from_string )
                 ] )
        in
        let%bind () =
          Async.after (Time.Span.create ~ms:rate_limit_interval ())
        in
        Deferred.return (batch_count := 0)
      else Deferred.return () )
    else fun () -> Deferred.return ()
  in

  (* contants regarding send amount and fees *)
  let base_send_amount = Currency.Amount.of_mina_string_exn "0" in
  let fee_amount =
    match txn_fee_option with
    | None ->
        Currency.Amount.to_fee
          (Option.value_exn
             (Currency.Amount.scale
                (Currency.Amount.of_fee minimum_user_command_fee)
                10 ) )
    | Some f ->
        Currency.Amount.to_fee (Currency.Amount.of_mina_string_exn f)
  in
  (* let acct_creation_fee = Currency.Amount.of_mina_string_exn "1" in *)
  let initial_send_amount =
    (* min_fee*num_txn_per_accts + base_send_amount*num_txn_per_accts + acct_creation_fee*num_accounts *)
    let total_send_value =
      Option.value_exn (Currency.Amount.scale base_send_amount num_txn_per_acct)
    in
    let total_fees =
      Option.value_exn
        (Currency.Amount.scale
           (Currency.Amount.of_fee fee_amount)
           num_txn_per_acct )
    in
    (* let total_acct_creation_fee =
         Option.value_exn
         (Currency.Amount.scale
            ( acct_creation_fee)
            num_accts)
       in *)
    Option.value_exn (Currency.Amount.add total_send_value total_fees)
  in

  let graphql_target_node =
    match graphql_target_node_option with Some s -> s | None -> "127.0.0.1"
  in
  let node_ingress_uri = ingress_uri ~graphql_target_node in

  (* Back-pressure from the target node's transaction pool. Once the pool is
     over capacity it evicts its lowest-fee commands along with every later
     nonce from the same sender, which leaves all of our subsequent commands
     building on a nonce the pool no longer has. Keeping the pool below its
     capacity avoids triggering that eviction in the first place. *)
  let pool_backpressure = ref pool_backpressure in
  (* Number of commands we may send before polling the pool again. Only a
     quarter of the headroom seen at the last poll is spent, so that several
     spammers sharing a pool do not each spend all of it and overshoot the
     high watermark; near the watermark this polls before every command. *)
  let pool_budget = ref 0 in
  let rec wait_for_pool_capacity ~paused () =
    if (not !pool_backpressure) || !pool_budget > 0 then Deferred.return ()
    else
      match%bind
        Client.get_transaction_pool_status ~logger node_ingress_uri
      with
      | Error e ->
          [%log warn]
            "txn burst tool: could not query the transaction pool status, \
             disabling back-pressure: %s"
            (Error.to_string_hum e) ;
          pool_backpressure := false ;
          Deferred.return ()
      | Ok { size; max_size; _ } ->
          let pause_at =
            Float.(to_int (pool_high_watermark *. of_int max_size))
          in
          let resume_at =
            Float.(to_int (pool_low_watermark *. of_int max_size))
          in
          if (paused && size > resume_at) || ((not paused) && size >= pause_at)
          then (
            if not paused then
              [%log info]
                "txn burst tool: transaction pool holds %d of %d commands, \
                 pausing until it drains to %d"
                size max_size resume_at ;
            let%bind () =
              Async.after (Time.Span.create ~ms:pool_poll_interval ())
            in
            wait_for_pool_capacity ~paused:true () )
          else (
            if paused then
              [%log info]
                "txn burst tool: transaction pool holds %d of %d commands, \
                 resuming"
                size max_size ;
            pool_budget := max 1 ((pause_at - size) / 4) ;
            Deferred.return () )
  in

  (* get the keypairs from files *)
  let%bind origin_keypair =
    get_keypair ~logger origin_sender_secret_key_path
      origin_sender_secret_key_pw_option
  in
  let origin_pub_key =
    origin_keypair.public_key |> Signature_lib.Public_key.compress
  in
  let%bind returner_keypair =
    get_keypair ~logger returner_secret_key_path returner_secret_key_pw_option
  in

  (* helper function that sends a transaction*)
  let do_txn ~(sender_kp : Keypair.t) ~(receiver_kp : Keypair.t) ~nonce =
    let receiver_pub_key =
      receiver_kp.public_key |> Signature_lib.Public_key.compress
    in
    [%log info]
      "txn burst tool: sending txn from sender= %s (nonce=%d) to receiver= %s \
       with amount=%s and fee=%s"
      (pub_key_to_string sender_kp.public_key)
      (UInt32.to_int nonce)
      (pub_key_to_string receiver_kp.public_key)
      (Currency.Amount.to_string initial_send_amount)
      (Currency.Fee.to_string fee_amount) ;
    let%bind () = wait_for_pool_capacity ~paused:false () in
    decr pool_budget ;
    let%bind res =
      Client.sign_and_send_payment ~logger node_ingress_uri
        ~sender_keypair:sender_kp ~receiver_pub_key ~amount:base_send_amount
        ~fee:fee_amount ~nonce ~memo:""
        ~valid_until:Mina_numbers.Global_slot_since_genesis.max_value
        ~signature_kind
    in
    let sent =
      match res with
      | Ok _ ->
          [%log info] "txn burst tool: txn sent successfully!" ;
          true
      | Error e ->
          [%log info] "txn burst tool: txn failed with error %s"
            (Error.to_string_hum e) ;
          (* The pool may have changed under us; look again before the next
             command. *)
          pool_budget := 0 ;
          false
    in
    let%map () = limit () in
    sent
  in

  (* there... *)
  let%bind () =
    (* in a previous version of the code there could be multiple returners, thus the iter.  keeping this structure in case we decide to change back later *)
    Deferred.List.iter [ returner_keypair ] ~f:(fun kp ->
        let%bind origin_nonce =
          get_nonce ~logger ~ingress_uri:node_ingress_uri
            ~pub_key:origin_pub_key
        in
        (* we could also get the origin nonce outside the iter and then just increment by 1 every iter *)
        do_txn ~sender_kp:origin_keypair ~receiver_kp:kp ~nonce:origin_nonce
        |> Deferred.ignore_m )
  in

  (* and back again... *)
  let%bind () =
    Deferred.List.iter [ returner_keypair ] ~f:(fun kp ->
        let%bind returner_nonce =
          get_nonce ~logger ~ingress_uri:node_ingress_uri
            ~pub_key:(Signature_lib.Public_key.compress kp.public_key)
        in
        let returner_pub_key =
          Signature_lib.Public_key.compress kp.public_key
        in
        let target_nonce =
          UInt32.add returner_nonce (UInt32.of_int num_txn_per_acct)
        in
        (* After a failure, resume from the nonce that the node expects next.
           If the pool evicted some of our commands, that is lower than the
           nonce we were about to send, and the evicted nonces are sent
           again. *)
        let resync_nonce ~nonce =
          let account_id =
            Account_id.create returner_pub_key Mina_base.Token_id.default
          in
          match%map
            Client.get_account_data node_ingress_uri ~logger ~account_id
          with
          | Ok res ->
              let inferred_nonce =
                Option.value res.inferred_nonce ~default:res.nonce
              in
              if UInt32.compare inferred_nonce nonce < 0 then
                [%log info]
                  "txn burst tool: the node no longer has nonces %d to %d, \
                   resending them"
                  (UInt32.to_int inferred_nonce)
                  (UInt32.to_int nonce - 1) ;
              inferred_nonce
          | Error e ->
              [%log warn]
                "txn burst tool: could not get nonce, retrying nonce %d: %s"
                (UInt32.to_int nonce) (Error.to_string_hum e) ;
              nonce
        in
        let rec do_command ~nonce ~consecutive_failures : unit Deferred.t =
          if UInt32.compare nonce target_nonce >= 0 then return ()
          else if consecutive_failures >= max_consecutive_failures then (
            [%log error]
              "txn burst tool: giving up after %d consecutive failures, with \
               %d of %d txns outstanding"
              consecutive_failures
              (UInt32.to_int target_nonce - UInt32.to_int nonce)
              num_txn_per_acct ;
            return () )
          else
            match%bind
              do_txn ~sender_kp:kp ~receiver_kp:origin_keypair ~nonce
            with
            | true ->
                do_command ~nonce:(UInt32.succ nonce) ~consecutive_failures:0
            | false ->
                let%bind () =
                  Async.after (Time.Span.create ~ms:retry_delay ())
                in
                let%bind nonce = resync_nonce ~nonce in
                do_command ~nonce
                  ~consecutive_failures:(consecutive_failures + 1)
        in
        do_command ~nonce:returner_nonce ~consecutive_failures:0 )
  in

  return ()

let output_there_and_back_cmds =
  let (module G) = Genesis_constants.profiled () in
  let genesis_constants = G.genesis_constants in
  let compile_config =
    Mina_compile_config.of_node_config (module Node_config)
  in
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Generate commands to send funds from a single account to many accounts, \
       then transfer them back again. The 'back again' commands are expressed \
       as GraphQL commands, so that we can pass a signature, rather than \
       having to load the secret key for each account"
    (let%map_open num_txn_per_acct =
       flag "--num-txn-per-acct" ~aliases:[ "num-txn-per-acct" ]
         ~doc:"NUM Number of transactions to run for each generated key"
         (required int)
     and txns_per_block =
       flag "--txn-capacity-per-block"
         ~aliases:[ "txn-capacity-per-block" ]
         ~doc:
           "NUM Number of transaction that a single block can hold.  Used for \
            rate limiting (default: 128)"
         (optional_with_default 128 int)
     and txn_fee_option =
       flag "--txn-fee" ~aliases:[ "txn-fee" ]
         ~doc:
           "FEE_AMOUNT Fee to set, a default is provided if this is not present"
         (optional string)
     and slot_time =
       flag "--slot-time" ~aliases:[ "slot-time" ]
         ~doc:
           "NUM_MILLISECONDS Slot duration in milliseconds. Used for rate \
            limiting (default: 180000)"
         (optional_with_default 180000 int)
     and fill_rate =
       flag "--fill-rate" ~aliases:[ "fill-rate" ]
         ~doc:
           "FILL_RATE The average rate of blocks per slot. Used for rate \
            limiting (default: 0.75)"
         (optional_with_default 0.75 float)
     and rate_limit =
       flag "--apply-rate-limit" ~aliases:[ "apply-rate-limit" ]
         ~doc:
           "TRUE/FALSE Whether to emit sleep commands between commands to \
            enforce sleeps (default: true)"
         (optional_with_default true bool)
     and rate_limit_level =
       flag "--rate-limit-level" ~aliases:[ "rate-limit-level" ]
         ~doc:
           "NUM Number of transactions that can be sent in a time interval \
            before hitting the rate limit. Used for rate limiting (default: \
            200)"
         (optional_with_default 200 int)
     and rate_limit_interval =
       flag "--rate-limit-interval" ~aliases:[ "rate-limit-interval" ]
         ~doc:
           "NUM_MILLISECONDS Interval that the rate-limiter is applied over. \
            Used for rate limiting (default: 300000)"
         (optional_with_default 300000 int)
     and pool_backpressure =
       flag "--pool-backpressure" ~aliases:[ "pool-backpressure" ]
         ~doc:
           "TRUE/FALSE Whether to pause sending while the target node's \
            transaction pool is nearly full (default: true)"
         (optional_with_default true bool)
     and pool_high_watermark =
       flag "--pool-high-watermark" ~aliases:[ "pool-high-watermark" ]
         ~doc:
           "FRACTION Fraction of the transaction pool's capacity at which to \
            pause sending (default: 0.9)"
         (optional_with_default 0.9 float)
     and pool_low_watermark =
       flag "--pool-low-watermark" ~aliases:[ "pool-low-watermark" ]
         ~doc:
           "FRACTION Fraction of the transaction pool's capacity that the pool \
            must drain to before sending resumes (default: 0.75)"
         (optional_with_default 0.75 float)
     and pool_poll_interval =
       flag "--pool-poll-interval" ~aliases:[ "pool-poll-interval" ]
         ~doc:
           "NUM_MILLISECONDS How often to poll the transaction pool while \
            paused (default: 1000)"
         (optional_with_default 1000 int)
     and retry_delay =
       flag "--retry-delay" ~aliases:[ "retry-delay" ]
         ~doc:
           "NUM_MILLISECONDS How long to wait after a failed submission before \
            resyncing the nonce and retrying (default: 5000)"
         (optional_with_default 5000 int)
     and max_consecutive_failures =
       flag "--max-consecutive-failures"
         ~aliases:[ "max-consecutive-failures" ]
         ~doc:
           "NUM Number of consecutive failed submissions after which to give \
            up (default: 60)"
         (optional_with_default 60 int)
     and origin_sender_secret_key_path =
       flag "--origin-sender-sk-path"
         ~aliases:[ "origin-sender-sk-path" ]
         ~doc:"PRIVATE_KEY Path to Private key to send the transactions from"
         (required string)
     and origin_sender_secret_key_pw_option =
       flag "--origin-sender-sk-pw" ~aliases:[ "origin-sender-sk-pw" ]
         ~doc:
           "PRIVATE_KEY Password to Private key to send the transactions from, \
            if this is not present then we use the env var MINA_PRIVKEY_PASS"
         (optional string)
     and returner_secret_key_path =
       flag "--returner-sk-path" ~aliases:[ "returner-sk-path" ]
         ~doc:
           "PRIVATE_KEY Path to Private key of account that returns the \
            transactions"
         (required string)
     and returner_secret_key_pw_option =
       flag "--returner-sk-pw" ~aliases:[ "returner-sk-pw" ]
         ~doc:
           "PRIVATE_KEY Password to Private key account that returns the \
            transactions, if this is not present then we use the env var \
            MINA_PRIVKEY_PASS"
         (optional string)
     and graphql_target_node_option =
       flag "--graphql-target-node" ~aliases:[ "graphql-target-node" ]
         ~doc:
           "URL The graphql node to send graphl commands to.  must be in \
            format `<ip>:<port>`.  default is `127.0.0.1:3085`"
         (optional string)
     and minimum_user_command_fee =
       let default = compile_config.default_transaction_fee in
       Cli_lib.Flag.fee_common
         ~minimum_user_command_fee:genesis_constants.minimum_user_command_fee
         ~default_transaction_fee:default
     in
     there_and_back_again ~num_txn_per_acct ~txns_per_block ~txn_fee_option
       ~slot_time ~fill_rate ~rate_limit ~rate_limit_level ~rate_limit_interval
       ~pool_backpressure ~pool_high_watermark ~pool_low_watermark
       ~pool_poll_interval ~retry_delay ~max_consecutive_failures
       ~origin_sender_secret_key_path ~origin_sender_secret_key_pw_option
       ~returner_secret_key_path ~returner_secret_key_pw_option
       ~graphql_target_node_option ~minimum_user_command_fee
       ~signature_kind:Mina_signature_kind.t_DEPRECATED )

let () =
  Command.run
    (Command.group
       ~summary:"Generate public keys for sending batches of transactions"
       [ ("gen-keys", output_keys)
       ; ("gen-txns", output_cmds)
       ; ("gen-there-and-back-txns", output_there_and_back_cmds)
       ] )
