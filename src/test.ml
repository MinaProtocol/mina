open Core_kernel
open Async_kernel

module Test (Swim : Swim.S) = struct
  let shutdown clients =
    List.iter clients ~f:(fun (_, c) ->
      Swim.stop c
    )

  let assert_equal ~msg x x' equal =
      if not (equal x x') then
        failwith ("Assertion Failure: " ^ msg)
      else
        ()

  let addr port =
    Host_and_port.of_string (sprintf "127.0.0.1:%d" (port + 8000))

  let swim_client idx =
    printf "Starting client %d\n" idx;
    (idx, Swim.connect
        ~config:
          { indirect_ping_count = 6
          ; protocol_period = Time.Span.of_sec 0.04
          ; rtt = Time.Span.of_sec 0.01
          }
        ~initial_peers:(List.init idx addr)
        ~me:(addr idx))

  let live_nodes_str client =
    let nodes = Swim.peers client in
    let strs = List.map nodes ~f:(fun node -> node
      |> Host_and_port.sexp_of_t
      |> Sexp.to_string
    ) in
    String.concat ~sep:"," strs

  let peers_and_self (idx, swim) =
    (addr idx) :: (Swim.peers swim)

  let same (ps : Host_and_port.t list) (ps' : Host_and_port.t list) : bool =
    Set.Poly.equal (Set.Poly.of_list ps) (Set.Poly.of_list ps')

  let wait_stabalize () =
    print_endline "Waiting a bit so the network can settle";
    Async.after (Time.Span.of_sec 0.5)

  let assert_stable (clients : (int * Swim.t) list) : unit =
    print_endline "Stability dump:";
    List.iter (List.take clients 3) (fun (idx, c) ->
      printf "%d:%s\n" idx (live_nodes_str c)
    );

    match clients with
    | [] -> ()
    | (idx, c)::xs ->
        List.iter xs ~f:(fun (idx', c') ->
          assert_equal ~msg:(Printf.sprintf "Same? %d and %d" idx idx')
            (peers_and_self (idx, c))
            (peers_and_self (idx', c'))
            same;
        )

  let create_with_delay_in_between ~delay ~count : (int * Swim.t) list Deferred.t =
    Deferred.List.init count (fun i ->
      let (idx, c_deferred) = swim_client i in
      let%bind c = c_deferred in
      let%map () = Async.after delay in
      (idx, c)
    )

  let test_kill_first_node ~count () : unit Deferred.t =
    let%bind clients =
      create_with_delay_in_between
        ~delay:(Time.Span.of_sec 0.1)
        ~count:count
    in

    let%bind () = wait_stabalize () in
    (* Full network *)
    assert_stable clients;

    match clients with
    | [] ->
      return (failwith "unreachable")
    | x::xs ->
      shutdown [x];
      let%bind () = wait_stabalize () in
      let%bind () = wait_stabalize () in
      (* Node0 dead *)
      assert_stable xs;

      let%bind c0::_ = create_with_delay_in_between
        ~delay:(Time.Span.of_sec 0.1)
        ~count:1 in
      let%map () = wait_stabalize () in
      (* Node0 revived *)
      assert_stable (c0::xs);

      shutdown (c0::xs)

  let test_network_partition ~count () : unit Deferred.t =
    let xs : int list = List.init count (fun i -> i) in
    match xs with
    | [] -> return ()
    | x::xs ->
      (* Partition node 0 from everything except node 1 *)
      List.iter xs (fun x' ->
        Swim.test_only_network_partition_add ~from:(addr x) ~to_:(addr x')
      );
      Swim.test_only_network_partition_remove ~from:(addr x) ~to_:(addr (List.nth_exn xs 0));

      let%map clients =
        create_with_delay_in_between
          ~delay:(Time.Span.of_sec 0.1)
          ~count:count
      in

      assert_stable clients;

      shutdown clients

end

module Mock = Test(Swim.Test)
module Real = Test(Swim.Udp)

;;

Log.current_level := (Log.ord Log.Warn);

don't_wait_for begin
  let%bind () = Mock.test_kill_first_node ~count:4 () in
  let%bind () = Mock.test_kill_first_node ~count:20 () in
  let%bind () = Mock.test_network_partition ~count:4 () in
  let%map () = Mock.test_network_partition ~count:20 () in
  print_endline "All tests pass!"
end;

Async.Scheduler.go ();


