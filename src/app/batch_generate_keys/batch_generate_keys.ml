open Core
open Async
open Signature_lib

let gen_secret_keys count =
  Quickcheck.random_value ~seed:`Nondeterministic
    (Quickcheck.Generator.list_with_length count Private_key.gen)

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
           Format.printf "%s@." (Public_key.Compressed.to_base58_check pk)))

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
               else incr batch_count) ;
           Format.printf
             "mina client send-payment --amount 1 --receiver %s --sender %s@."
             (Public_key.Compressed.to_base58_check pk)
             sender_key))

(* Shamelessly copied from src/app/cli/src/init/graphql_queries.ml and tweaked*)
module Send_payment =
[%graphql
{|
mutation ($sender: PublicKey!,
          $receiver: PublicKey!,
          $amount: UInt64!,
          $token: UInt64,
          $fee: UInt64!,
          $nonce: UInt32,
          $memo: String,
          $field: String,
          $scalar: String) {
  sendPayment(input:
    {from: $sender, to: $receiver, amount: $amount, token: $token, fee: $fee, nonce: $nonce, memo: $memo},
    signature: {field: $field, scalar: $scalar}) {
    payment {
      id
    }
  }
}
|}]

let make_graphql_signed_transaction ~sender_priv_key ~receiver ~amount ~fee =
  let sender_pub_key =
    Public_key.of_private_key_exn sender_priv_key |> Public_key.compress
  in
  let receiver_pub_key = Public_key.Compressed.of_base58_check_exn receiver in
  let field, scalar =
    Mina_base.Signed_command.sign_payload sender_priv_key
      { common =
          { fee
          ; fee_token = Mina_base.Token_id.default
          ; fee_payer_pk = sender_pub_key
          ; nonce = Mina_numbers.Account_nonce.zero
          ; valid_until = Mina_numbers.Global_slot.max_value
          ; memo = Mina_base.Signed_command_memo.empty
          }
      ; body =
          Payment
            { source_pk = sender_pub_key
            ; receiver_pk = receiver_pub_key
            ; token_id = Mina_base.Token_id.default
            ; amount
            }
      }
  in
  let graphql_query =
    Send_payment.make
      ~receiver:(Graphql_lib.Encoders.public_key receiver_pub_key)
      ~sender:(Graphql_lib.Encoders.public_key sender_pub_key)
      ~amount:(Graphql_lib.Encoders.amount amount)
      ~fee:(Graphql_lib.Encoders.fee fee)
      ~field:(Snark_params.Tick.Field.to_string field)
      ~scalar:(Snark_params.Tick.Inner_curve.Scalar.to_string scalar)
      ()
  in
  let graphql_query_json =
    `Assoc
      [ ("query", `String graphql_query#query)
      ; ("variables", graphql_query#variables)
      ]
  in
  Format.sprintf
    "curl 'http://127.0.0.1:3085/graphql' -X POST -H 'content-type: \
     application/json' --data '%s'@."
    (Yojson.Basic.to_string graphql_query_json)

let there_and_back_again ~num_accts ~num_txn_per_acct ~txns_per_block ~slot_time
    ~fill_rate ~rate_limit ~rate_limit_level ~rate_limit_interval
    ~origin_sender_public_key_option ~origin_sender_secret_key_path_option () =
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
  let base_send_amount = Currency.Amount.of_formatted_string "0" in
  let fee_amount = Mina_base.Signed_command.minimum_fee in
  let acct_creation_fee = Currency.Amount.of_formatted_string "1" in
  let initial_send_amount =
    (* min_fee*num_txn_per_accts + base_send_amount*num_txn_per_accts + acct_creation_fee *)
    let total_send_value =
      Option.value_exn (Currency.Amount.scale base_send_amount num_txn_per_acct)
    in
    let total_fees =
      Option.value_exn
        (Currency.Amount.scale
           (Currency.Amount.of_fee fee_amount)
           num_txn_per_acct)
    in
    Option.value_exn
      (Currency.Amount.add total_fees
         (Option.value_exn
            (Currency.Amount.add total_send_value acct_creation_fee)))
  in
  let generated_secrets = gen_secret_keys num_accts in
  let limit =
    Option.iter rate_limit ~f:(fun rate_limit ->
        if !batch_count >= rate_limit then (
          Format.printf "sleep %f@." Float.(of_int rate_limit_interval /. 1000.) ;
          batch_count := 0 )
        else incr batch_count)
  in

  (* get the origin_pk and the origin_sk if possible *)
  let open Deferred.Let_syntax in
  let%bind (use_graphql, origin_sk_option)
             : bool * Marlin_plonk_bindings_pasta_fq.t option =
    if Option.is_some origin_sender_public_key_option then
      Deferred.return (false, None)
    else if Option.is_some origin_sender_secret_key_path_option then
      let%bind keypair =
        Secrets.Keypair.read_exn'
          (Option.value_exn origin_sender_secret_key_path_option)
      in
      let origin_sk = keypair.private_key in
      Deferred.return (true, Some origin_sk)
    else exit 1
  in
  let origin_pk : string =
    if not use_graphql then Option.value_exn origin_sender_public_key_option
    else
      let origin_sk = Option.value_exn origin_sk_option in
      origin_sk |> Public_key.of_private_key_exn |> Public_key.compress
      |> Public_key.Compressed.to_base58_check
  in

  (* there... *)
  if not use_graphql then
    List.iter generated_secrets ~f:(fun sk ->
        let acct_pk =
          Public_key.of_private_key_exn sk
          |> Public_key.compress |> Public_key.Compressed.to_base58_check
        in
        let transaction_command =
          Format.sprintf
            "mina client send-payment --amount %s --fee %s --receiver %s \
             --sender %s@."
            (initial_send_amount |> Currency.Amount.to_formatted_string)
            ( fee_amount |> Currency.Amount.of_fee
            |> Currency.Amount.to_formatted_string )
            acct_pk origin_pk
        in
        Format.print_string transaction_command ;
        limit)
  else
    List.iter generated_secrets ~f:(fun sk ->
        let acct_pk = Public_key.of_private_key_exn sk in
        let origin_sk = Option.value_exn origin_sk_option in
        let transaction_command =
          make_graphql_signed_transaction ~sender_priv_key:origin_sk
            ~receiver:Public_key.(Compressed.to_base58_check (compress acct_pk))
            ~amount:initial_send_amount ~fee:fee_amount
        in
        Format.print_string transaction_command ;
        limit) ;

  (* and back again... *)
  Deferred.return
    (List.iter generated_secrets ~f:(fun sk ->
         let rec do_command n =
           let transaction_command =
             make_graphql_signed_transaction ~sender_priv_key:sk
               ~receiver:origin_pk ~amount:base_send_amount ~fee:fee_amount
           in
           Format.print_string transaction_command ;
           limit ;
           if n > 1 then do_command (n - 1)
         in
         do_command num_txn_per_acct))

let output_there_and_back_cmds =
  let open Command.Let_syntax in
  Command.async
    ~summary:
      "Generate commands to send funds from a single account to many accounts, \
       then transfer them back again. The 'back again' commands are expressed \
       as GraphQL commands, so that we can pass a signature, rather than \
       having to load the secret key for each account"
    (let%map_open num_accts =
       flag "--num-accts" ~aliases:[ "num-accts" ]
         ~doc:"NUM Number of keys to generate" (required int)
     and num_txn_per_acct =
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
     and origin_sender_public_key_option =
       flag "--origin-sender-pk" ~aliases:[ "origin-sender-pk" ]
         ~doc:"PUBLIC_KEY Public key to send the transactions from"
         (optional string)
     and origin_sender_secret_key_path_option =
       flag "--origin-sender-sk-path" ~aliases:[ "origin-sender-sk" ]
         ~doc:"PRIVATE_KEY Path to Private key to send the transactions from"
         (optional string)
     in
     there_and_back_again ~num_accts ~num_txn_per_acct ~txns_per_block
       ~slot_time ~fill_rate ~rate_limit ~rate_limit_level ~rate_limit_interval
       ~origin_sender_public_key_option ~origin_sender_secret_key_path_option)

let () =
  Command.run
    (Command.group
       ~summary:"Generate public keys for sending batches of transactions"
       [ ("gen-keys", output_keys)
       ; ("gen-txns", output_cmds)
       ; ("gen-there-and-back-txns", output_there_and_back_cmds)
       ])
