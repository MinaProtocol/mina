open Core
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
       flag "--count" ~aliases:["count"] ~doc:"NUM Number of keys to generate"
         (required int)
     in
     fun () ->
       List.iter (gen_keys count) ~f:(fun pk ->
           Format.printf "%s@." (Public_key.Compressed.to_base58_check pk) ))

let output_cmds =
  let open Command.Let_syntax in
  Command.basic ~summary:"Generate the given number of public keys on stdout"
    (let%map_open count =
       flag "--count" ~aliases:["count"] ~doc:"NUM Number of keys to generate"
         (required int)
     and txns_per_block =
       flag "--txn-capacity-per-block" ~aliases:["txn-capacity-per-block"]
         ~doc:
           "NUM Transaction capacity per block. Used for rate limiting. \
            (default: 128)"
         (optional_with_default 128 int)
     and slot_time =
       flag "--slot-time" ~aliases:["slot-time"]
         ~doc:
           "NUM_MILLISECONDS Slot duration in milliseconds. (default: 180000)"
         (optional_with_default 180000 int)
     and fill_rate =
       flag "--fill-rate" ~aliases:["fill-rate"]
         ~doc:"FILL_RATE Fill rate (default: 0.75)"
         (optional_with_default 0.75 float)
     and rate_limit =
       flag "--apply-rate-limit" ~aliases:["apply-rate-limit"]
         ~doc:
           "TRUE/FALSE Whether to emit sleep commands between commands to \
            enforce sleeps (default: true)"
         (optional_with_default true bool)
     and rate_limit_level =
       flag "--rate-limit-level" ~aliases:["rate-limit-level"]
         ~doc:
           "NUM Number of transactions that can be sent in a time interval \
            before hitting the rate limit (default: 200)"
         (optional_with_default 200 int)
     and rate_limit_interval =
       flag "--rate-limit-interval" ~aliases:["rate-limit-interval"]
         ~doc:
           "NUM_MILLISECONDS Interval that the rate-limiter is applied over \
            (default: 300000)"
         (optional_with_default 300000 int)
     and sender_key =
       flag "--sender-pk" ~aliases:["sender-pk"]
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
             sender_key ))

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

let output_there_and_back_cmds =
  let open Command.Let_syntax in
  Command.basic ~summary:"Generate commands to send funds from a single account to many accounts, then transfer them back again. The 'back again' commands are expressed as GraphQL commands, so that we can pass a signature, rather than having to load the secret key for each account"
    (let%map_open count =
       flag "--count" ~aliases:["count"] ~doc:"NUM Number of keys to generate"
         (required int)
     and txns_per_block =
       flag "--txn-capacity-per-block" ~aliases:["txn-capacity-per-block"]
         ~doc:
           "NUM Transaction capacity per block. Used for rate limiting. \
            (default: 128)"
         (optional_with_default 128 int)
     and slot_time =
       flag "--slot-time" ~aliases:["slot-time"]
         ~doc:
           "NUM_MILLISECONDS Slot duration in milliseconds. (default: 180000)"
         (optional_with_default 180000 int)
     and fill_rate =
       flag "--fill-rate" ~aliases:["fill-rate"]
         ~doc:"FILL_RATE Fill rate (default: 0.75)"
         (optional_with_default 0.75 float)
     and rate_limit =
       flag "--apply-rate-limit" ~aliases:["apply-rate-limit"]
         ~doc:
           "TRUE/FALSE Whether to emit sleep commands between commands to \
            enforce sleeps (default: true)"
         (optional_with_default true bool)
     and rate_limit_level =
       flag "--rate-limit-level" ~aliases:["rate-limit-level"]
         ~doc:
           "NUM Number of transactions that can be sent in a time interval \
            before hitting the rate limit (default: 200)"
         (optional_with_default 200 int)
     and rate_limit_interval =
       flag "--rate-limit-interval" ~aliases:["rate-limit-interval"]
         ~doc:
           "NUM_MILLISECONDS Interval that the rate-limiter is applied over \
            (default: 300000)"
         (optional_with_default 300000 int)
     and sender_key =
       flag "--sender-pk" ~aliases:["sender-pk"]
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
       let sks = gen_secret_keys count in
       List.iter sks ~f:(fun sk ->
           let pk = Public_key.of_private_key_exn sk in
           Option.iter rate_limit ~f:(fun rate_limit ->
               if !batch_count >= rate_limit then (
                 Format.printf "sleep %f@."
                   Float.(of_int rate_limit_interval /. 1000.) ;
                 batch_count := 0 )
               else incr batch_count ) ;
           Format.printf
             "mina client send-payment --amount 1 --receiver %s --sender %s@."
             Public_key.(Compressed.to_base58_check (compress pk))
             sender_key ) ;
       List.iter sks ~f:(fun sk ->
           let pk = Public_key.of_private_key_exn sk |> Public_key.compress in
           Option.iter rate_limit ~f:(fun rate_limit ->
               if !batch_count >= rate_limit then (
                 Format.printf "sleep %f@."
                   Float.(of_int rate_limit_interval /. 1000.) ;
                 batch_count := 0 )
               else incr batch_count ) ;
          let fee = Mina_base.Signed_command.minimum_fee in
          let sender = Public_key.Compressed.of_base58_check_exn sender_key in
          let amount = Currency.Amount.of_formatted_string "1" in
           let (field, scalar) =
             Mina_base.Signed_command.sign_payload sk
          {common= { fee
          ; fee_token= Mina_base.Token_id.default
          ; fee_payer_pk= pk
          ; nonce= Mina_numbers.Account_nonce.zero
          ; valid_until= Mina_numbers.Global_slot.max_value
          ; memo= Mina_base.Signed_command_memo.empty
          }; body= Payment {source_pk= pk; receiver_pk= sender; token_id= Mina_base.Token_id.default; amount}}
          in
           let graphql_query =
               Send_payment.make
                ~receiver:(Graphql_lib.Encoders.public_key sender)
                ~sender:(Graphql_lib.Encoders.public_key pk)
                ~amount:(Graphql_lib.Encoders.amount amount) ~fee:(Graphql_lib.Encoders.fee fee)
                ~field:(Snark_params.Tick.Field.to_string field)
                ~scalar:(Snark_params.Tick.Inner_curve.Scalar.to_string scalar)
                ()
           in
           let graphql_query_json =
             `Assoc [("query", `String graphql_query#query); ("variables", graphql_query#variables)]
           in
           Format.printf
             "curl 'http://127.0.0.1:3085/graphql' -X POST -H 'content-type: application/json' --data '%s'@."
             (Yojson.Basic.to_string graphql_query_json) )
       )

let () =
  Command.run
    (Command.group
       ~summary:"Generate public keys for sending batches of transactions"
       [("gen-keys", output_keys); ("gen-txns", output_cmds); ("gen-there-and-back-txns", output_there_and_back_cmds)])
