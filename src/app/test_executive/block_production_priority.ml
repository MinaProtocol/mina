open Core
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  (* TODO: find a way to avoid this type alias (first class module signatures restrictions make this tricky) *)
  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        (let open Block_producer in
        [ { balance = "9999999"; timing = Untimed }
        ; { balance = "9999999"; timing = Untimed }
        ])
    }

  let wait_for_all_to_initialize ~logger network t =
    let open Malleable_error.Let_syntax in
    let all_nodes = Network.all_nodes network in
    let n = List.length all_nodes in
    List.mapi all_nodes ~f:(fun i node ->
        let%map () = wait_for t (Wait_condition.node_to_initialize node) in
        [%log info] "Block producer %d (of %d) initialized" (i + 1) n ;
        ())
    |> Malleable_error.all_unit

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "starting..." ;
    let%bind () = wait_for_all_to_initialize ~logger network t in
    [%log info] "done waiting for initializations" ;
    let receiver_bp = List.nth_exn (Network.block_producers network) 0 in
    let%bind receiver_pub_key = Util.pub_key_of_node receiver_bp in
    let sender_bp = List.nth_exn (Network.block_producers network) 1 in
    let%bind sender_pub_key = Util.pub_key_of_node sender_bp in
    let tps = 1 in
    let window_ms =
      (Network.constraint_constants network).block_window_duration_ms
    in
    let num_slots = 10 in
    let num_payments = tps * num_slots * window_ms / 1000 in
    let fee = Currency.Fee.of_int 10_000_000 in
    let amount = Currency.Amount.of_int 10_000_000 in
    [%log info] "will now send %d payments" num_payments;
    let get_metrics node =
      Async_kernel.Deferred.bind
        (Network.Node.get_metrics ~logger node)
        ~f:Malleable_error.or_hard_error
    in
    let end_t = Time.add (Time.now ()) (Time.Span.of_ms @@ float_of_int @@ num_slots * window_ms) in
    let%bind () = Network.Node.must_send_payment
              ~initial_delay_sec:1.
              ~repeat_count:(Unsigned.UInt32.of_int num_payments)
              ~repeat_delay_ms:(Unsigned.UInt32.of_int @@ 1000 / tps)
              ~logger ~sender_pub_key ~receiver_pub_key ~amount ~fee sender_bp in
    let%bind () = Async_kernel.Deferred.bind (Async.after (Time.diff end_t @@ Time.now ())) ~f:(const Malleable_error.ok_unit) in
    let%bind { block_production_delay = snd_delay } = get_metrics sender_bp in
    let%bind { block_production_delay = rcv_delay } = get_metrics receiver_bp in
    let gt0 a = a > 0 in
    let rcv_delay0 = List.nth_exn rcv_delay 0 in
    let snd_delay0 = List.nth_exn snd_delay 0 in
    let%map () =
      Malleable_error.ok_if_true
        ~error:(Error.of_string "unexpected block production delays")
        ( rcv_delay0 > 0 && snd_delay0 > 0
        && List.is_empty (List.filter ~f:gt0 @@ List.tl_exn rcv_delay)
        && List.is_empty (List.filter ~f:gt0 @@ List.tl_exn snd_delay)
        && rcv_delay0 + snd_delay0 >= num_slots - 1 )
    in
    [%log info] "block_production_priority test: test finished!!"
end
