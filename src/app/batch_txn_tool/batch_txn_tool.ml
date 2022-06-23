open Core
open Async
open Signature_lib
open Txn_tool_graphql
open Unsigned

(* let gen_secret_keys count =
   Quickcheck.random_value ~seed:`Nondeterministic
     (Quickcheck.Generator.list_with_length count Private_key.gen) *)

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

let pk_to_str pk =
  pk |> Public_key.compress |> Public_key.Compressed.to_base58_check

let there_and_back_again ~num_txn_per_acct ~txns_per_block ~slot_time ~fill_rate
    ~txn_fee_option ~rate_limit ~rate_limit_level ~rate_limit_interval
    ~origin_sender_secret_key_path
    ~(origin_sender_secret_key_pw_option : string option)
    ~returner_secret_key_path ~(returner_secret_key_pw_option : string option)
    ~graphql_target_node_option () =
  let open Deferred.Let_syntax in
  (* define the rate limiting function *)
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
    (* TODO, in the current state of things, this function counts to limit_level of transactions, and then slaps a pause after it.  This happens even if the transactions themselves took far longer than the pause.  It thereby makes the rate slower and more conservative than would appear.  In future, perhaps implement with some sort of Timer *)
    if rate_limit then ( fun () ->
      incr batch_count ;
      if !batch_count >= limit_level then
        let%bind () =
          Deferred.return
            (Format.printf
               "txn burst tool: rate limiting, pausing for %d milliseconds... \
                @."
               rate_limit_interval )
        in
        let%bind () =
          Async.after (Time.Span.create ~ms:rate_limit_interval ())
        in
        Deferred.return (batch_count := 0)
      else Deferred.return () )
    else fun () -> Deferred.return ()
  in

  (* contants regarding send amount and fees *)
  let base_send_amount = Currency.Amount.of_formatted_string "0" in
  let fee_amount =
    match txn_fee_option with
    | None ->
        Currency.Amount.to_fee
          (Option.value_exn
             (Currency.Amount.scale
                (Currency.Amount.of_fee Mina_base.Signed_command.minimum_fee)
                10 ) )
    | Some f ->
        Currency.Amount.to_fee (Currency.Amount.of_formatted_string f)
  in
  (* let acct_creation_fee = Currency.Amount.of_formatted_string "1" in *)
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

  (* helper function for getting a keypair from a local path *)
  let get_keypair path pw_option =
    let%bind keypair =
      match pw_option with
      | Some s ->
          Secrets.Keypair.read_exn ~privkey_path:path
            ~password:(s |> Bytes.of_string |> Deferred.return |> Lazy.return)
      | None ->
          Secrets.Keypair.read_exn' path
    in
    let pk_str =
      keypair.public_key |> Public_key.compress
      |> Public_key.Compressed.to_base58_check
    in
    Format.printf "txn burst tool: successfully got keypair.  pk= %s@." pk_str ;
    return keypair
  in

  (* get the keypairs from files *)
  let%bind origin_keypair =
    get_keypair origin_sender_secret_key_path origin_sender_secret_key_pw_option
  in
  let%bind returner_keypair =
    get_keypair returner_secret_key_path returner_secret_key_pw_option
  in

  (* helper function that uses graphql command to get the nonce of a node*)
  let get_nonce pk =
    Format.printf
      "txn burst tool: using graphql to get the nonce of the account= %s, \
       using graphql target node= %s@."
      (pk_to_str pk) graphql_target_node ;
    let%bind nonce =
      let%bind querry_result =
        get_account_data ~graphql_target_node ~public_key:pk
      in
      match querry_result with
      | Ok n ->
          return (UInt32.of_int n)
      | Error _ ->
          Format.printf "txn burst tool: could not get nonce of pk= %s@."
            (pk_to_str pk) ;
          exit 1
    in
    Format.printf "txn burst tool: nonce obtained, nonce= %d@."
      (UInt32.to_int nonce) ;
    return nonce
  in

  (* helper function that sends a transaction*)
  let do_txn ~(sender_kp : Keypair.t) ~(receiver_kp : Keypair.t) ~nonce =
    Format.printf
      "txn burst tool: sending txn from sender= %s (nonce=%d) to receiver= %s \
       with amount=%s and fee=%s@."
      (pk_to_str sender_kp.public_key)
      (UInt32.to_int nonce)
      (pk_to_str receiver_kp.public_key)
      (Currency.Amount.to_string initial_send_amount)
      (Currency.Fee.to_string fee_amount) ;
    let%bind res =
      send_signed_transaction ~sender_priv_key:sender_kp.private_key ~nonce
        ~receiver_pub_key:receiver_kp.public_key ~amount:initial_send_amount
        ~fee:fee_amount ~graphql_target_node
    in
    let%bind () =
      match res with
      | Ok _ ->
          return (Format.printf "txn burst tool: txn sent successfully!@.")
      | Error e ->
          return
            (Format.printf "txn burst tool: txn failed with error %s@."
               (Error.to_string_hum e) )
    in
    limit ()
  in

  (* there... *)
  let%bind () =
    (* in a previous version of the code there could be multiple returners, thus the iter.  keeping this structure in case we decide to change back later *)
    Deferred.List.iter [ returner_keypair ] ~f:(fun kp ->
        let%bind origin_nonce = get_nonce origin_keypair.public_key in
        (* we could also get the origin nonce outside the iter and then just increment by 1 every iter *)
        do_txn ~sender_kp:origin_keypair ~receiver_kp:kp ~nonce:origin_nonce )
  in

  (* and back again... *)
  let%bind () =
    Deferred.List.iter [ returner_keypair ] ~f:(fun kp ->
        let%bind returner_nonce = get_nonce kp.public_key in
        let rec do_command n : unit Deferred.t =
          (* nce = returner_nonce + ( num_txn_per_acct - n ) *)
          let nce =
            UInt32.add returner_nonce (UInt32.of_int (num_txn_per_acct - n))
          in
          let%bind () =
            do_txn ~sender_kp:kp ~receiver_kp:origin_keypair ~nonce:nce
          in
          if n > 1 then do_command (n - 1) else return ()
        in
        do_command num_txn_per_acct )
  in
  return ()

let output_there_and_back_cmds =
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
     in
     there_and_back_again ~num_txn_per_acct ~txns_per_block ~txn_fee_option
       ~slot_time ~fill_rate ~rate_limit ~rate_limit_level ~rate_limit_interval
       ~origin_sender_secret_key_path ~origin_sender_secret_key_pw_option
       ~returner_secret_key_path ~returner_secret_key_pw_option
       ~graphql_target_node_option )

let () =
  Command.run
    (Command.group
       ~summary:"Generate public keys for sending batches of transactions"
       [ ("gen-keys", output_keys)
       ; ("gen-txns", output_cmds)
       ; ("gen-there-and-back-txns", output_there_and_back_cmds)
       ] )
