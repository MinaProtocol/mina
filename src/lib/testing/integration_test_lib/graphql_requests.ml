open Async
open Mina_base

(* Re-export types and functions from the shared mina_graphql_client library *)
module Graphql = Mina_graphql_client.Queries
include Mina_graphql_client.Types
include Mina_graphql_client.Client

(* Helper to convert Deferred.Or_error to Malleable_error *)
let lift f = f |> Deferred.bind ~f:Malleable_error.or_hard_error

(* must_* wrappers that convert Deferred.Or_error to Malleable_error *)
let must_get_peer_id ~logger node_uri = get_peer_id ~logger node_uri |> lift

let must_get_global_slot_since_hard_fork ~logger node_uri =
  get_global_slot_since_hard_fork ~logger node_uri |> lift

let must_get_best_chain ?max_length ~logger node_uri =
  get_best_chain ?max_length ~logger node_uri |> lift

let must_get_account_data ~logger node_uri ~account_id =
  get_account_data ~logger node_uri ~account_id |> lift

let must_send_online_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount
    ~fee =
  send_online_payment ~logger t ~sender_pub_key ~receiver_pub_key ~amount ~fee
  |> lift

let must_send_delegation ~logger node_uri ~sender_pub_key
    ~(receiver_pub_key : Account.key) ~fee =
  send_delegation ~logger node_uri ~sender_pub_key ~receiver_pub_key ~fee
  |> lift

let must_send_payment_with_raw_sig ~logger node_uri ~sender_pub_key
    ~receiver_pub_key ~amount ~fee ~nonce ~memo
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t) ~raw_signature =
  send_payment_with_raw_sig ~logger node_uri ~sender_pub_key ~receiver_pub_key
    ~amount ~fee ~nonce ~memo
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t)
    ~raw_signature
  |> lift

let must_send_delegation_with_raw_sig ~logger node_uri ~sender_pub_key
    ~receiver_pub_key ~fee ~nonce ~memo
    ~(valid_until : Mina_numbers.Global_slot_since_genesis.t) ~raw_signature =
  send_delegation_with_raw_sig ~logger node_uri ~sender_pub_key
    ~receiver_pub_key ~fee ~nonce ~memo ~valid_until ~raw_signature
  |> lift

let must_send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
    ~receiver_pub_key ~amount ~fee =
  send_test_payments ~repeat_count ~repeat_delay_ms ~logger t ~senders
    ~receiver_pub_key ~amount ~fee
  |> lift

let must_set_snark_worker ~logger t ~new_snark_pub_key =
  set_snark_worker ~logger t ~new_snark_pub_key |> lift

let must_set_snark_work_fee ~logger t ~new_snark_work_fee =
  set_snark_work_fee ~logger t ~new_snark_work_fee |> lift

let must_get_detailed_best_chain ?max_length ~logger node_uri =
  get_detailed_best_chain ?max_length ~logger node_uri |> lift

let export_genesis_ledger ~logger node_uri =
  let open Deferred.Let_syntax in
  [%log info] "Exporting genesis ledger"
    ~metadata:[ ("node_uri", `String (Uri.to_string node_uri)) ] ;
  let q = Graphql.Genesis_ledger_export.(make @@ makeVariables ()) in
  let%bind response =
    exec_graphql_request ~logger ~node_uri ~query_name:"fork_config" q
  in
  Result.bind response (fun r ->
      (r.Graphql.Genesis_ledger_export.fork_config :> Yojson.Safe.t)
      |> Runtime_config.of_yojson
      |> Result.map_error (fun msg -> Core.Error.of_string msg) )
  |> Malleable_error.or_hard_error
