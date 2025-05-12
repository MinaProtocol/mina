open Core
open Async
open Pipe_lib

let wait_for ?(timeout = 0.1) () = after (Time.Span.of_sec timeout)

(* Helper function to check if a Strict_pipe reader is closed by trying to read from it *)
let is_reader_closed reader =
  match
    Async.Thread_safe.block_on_async_exn (fun () ->
        return (Pipe.is_closed (Strict_pipe.Reader.to_linear_pipe reader).pipe) )
  with
  | result ->
      result
  | exception _ ->
      true
(* If we can't read, assume it's closed *)

(* Strict_pipe tests *)
module Strict_pipe_tests = struct
  let test_close_writer () =
    let _, writer = Strict_pipe.create Synchronous in
    Alcotest.(check bool)
      "Writer is not closed initially" false
      (Strict_pipe.Writer.is_closed writer) ;
    Strict_pipe.Writer.close writer ;
    Alcotest.(check bool)
      "Writer is closed after close" true
      (Strict_pipe.Writer.is_closed writer)

  let test_close_buffered_writer () =
    let _, writer =
      Strict_pipe.create (Buffered (`Capacity 64, `Overflow Crash))
    in
    Alcotest.(check bool)
      "Buffered writer is not closed initially" false
      (Strict_pipe.Writer.is_closed writer) ;
    Strict_pipe.Writer.close writer ;
    Alcotest.(check bool)
      "Buffered writer is closed after close" true
      (Strict_pipe.Writer.is_closed writer)

  let test_map_closure () =
    let input_reader, input_writer = Strict_pipe.create Synchronous in
    Alcotest.(check bool)
      "Input writer is not closed initially" false
      (Strict_pipe.Writer.is_closed input_writer) ;
    let output_reader = Strict_pipe.Reader.map ~f:Fn.id input_reader in
    Alcotest.(check bool)
      "Output reader is not closed initially" false
      (is_reader_closed output_reader) ;
    Strict_pipe.Writer.close input_writer ;
    Alcotest.(check bool)
      "Input writer is closed after close" true
      (Strict_pipe.Writer.is_closed input_writer) ;
    Alcotest.(check bool)
      "Output reader is closed when input writer is closed" true
      (is_reader_closed output_reader)

  let test_filter_map_closure () =
    let input_reader, input_writer = Strict_pipe.create Synchronous in
    Alcotest.(check bool)
      "Input writer is not closed initially" false
      (Strict_pipe.Writer.is_closed input_writer) ;
    let output_reader =
      Strict_pipe.Reader.filter_map ~f:(Fn.const (Some 1)) input_reader
    in
    Alcotest.(check bool)
      "Output reader is not closed initially" false
      (is_reader_closed output_reader) ;
    Strict_pipe.Writer.close input_writer ;
    Alcotest.(check bool)
      "Input writer is closed after close" true
      (Strict_pipe.Writer.is_closed input_writer) ;
    Alcotest.(check bool)
      "Output reader is closed when input writer is closed" true
      (is_reader_closed output_reader)

  let test_fork_closure () =
    let input_reader, input_writer = Strict_pipe.create Synchronous in
    Alcotest.(check bool)
      "Input writer is not closed initially" false
      (Strict_pipe.Writer.is_closed input_writer) ;
    let output_reader1, output_reader2 =
      Strict_pipe.Reader.Fork.two input_reader
    in
    Alcotest.(check bool)
      "Output reader 1 is not closed initially" false
      (is_reader_closed output_reader1) ;
    Alcotest.(check bool)
      "Output reader 2 is not closed initially" false
      (is_reader_closed output_reader2) ;
    Strict_pipe.Writer.close input_writer ;
    Alcotest.(check bool)
      "Input writer is closed after close" true
      (Strict_pipe.Writer.is_closed input_writer) ;
    Alcotest.(check bool)
      "Output reader 1 is closed when input writer is closed" true
      (is_reader_closed output_reader1) ;
    Alcotest.(check bool)
      "Output reader 2 is closed when input writer is closed" true
      (is_reader_closed output_reader2)

  let test_partition_map3_closure () =
    let input_reader, input_writer = Strict_pipe.create Synchronous in
    Alcotest.(check bool)
      "Input writer is not closed initially" false
      (Strict_pipe.Writer.is_closed input_writer) ;
    let output_reader1, output_reader2, output_reader3 =
      Strict_pipe.Reader.partition_map3 input_reader ~f:(fun _ -> `Fst 1)
    in
    Alcotest.(check bool)
      "Output reader 1 is not closed initially" false
      (is_reader_closed output_reader1) ;
    Alcotest.(check bool)
      "Output reader 2 is not closed initially" false
      (is_reader_closed output_reader2) ;
    Alcotest.(check bool)
      "Output reader 3 is not closed initially" false
      (is_reader_closed output_reader3) ;
    Strict_pipe.Writer.close input_writer ;
    Alcotest.(check bool)
      "Input writer is closed after close" true
      (Strict_pipe.Writer.is_closed input_writer) ;
    Alcotest.(check bool)
      "Output reader 1 is closed when input writer is closed" true
      (is_reader_closed output_reader1) ;
    Alcotest.(check bool)
      "Output reader 2 is closed when input writer is closed" true
      (is_reader_closed output_reader2) ;
    Alcotest.(check bool)
      "Output reader 3 is closed when input writer is closed" true
      (is_reader_closed output_reader3)

  let test_transfer_closure () =
    let input_reader, input_writer = Strict_pipe.create Synchronous
    and _, output_writer = Strict_pipe.create Synchronous in
    Alcotest.(check bool)
      "Input writer is not closed initially" false
      (Strict_pipe.Writer.is_closed input_writer) ;
    Alcotest.(check bool)
      "Output writer is not closed initially" false
      (Strict_pipe.Writer.is_closed output_writer) ;
    let (_ : unit Deferred.t) =
      Strict_pipe.transfer input_reader output_writer ~f:Fn.id
    in
    Strict_pipe.Writer.close input_writer ;
    Alcotest.(check bool)
      "Input writer is closed after close" true
      (Strict_pipe.Writer.is_closed input_writer) ;
    Alcotest.(check bool)
      "Output writer is closed when input writer is closed" true
      (Strict_pipe.Writer.is_closed output_writer)

  let test_merge_iter_filters_closed_pipes () =
    let run_test () =
      let reader1, writer1 =
        Strict_pipe.create
          (Buffered (`Capacity 10, `Overflow (Drop_head ignore)))
      in
      let reader2, writer2 =
        Strict_pipe.create
          (Buffered (`Capacity 10, `Overflow (Drop_head ignore)))
      in
      Strict_pipe.Reader.Merge.iter [ reader1; reader2 ] ~f:(fun _ ->
          Deferred.unit )
      |> don't_wait_for ;
      Strict_pipe.Writer.write writer1 1 ;
      Strict_pipe.Writer.write writer2 2 ;
      Strict_pipe.Writer.close writer1 ;
      let%map () = wait_for () in
      Strict_pipe.Writer.write writer2 3 ;
      (* If we got here without error, the test passed *)
      Alcotest.(check bool) "Test completed without error" true true
    in
    match Async.Thread_safe.block_on_async_exn run_test with
    | () ->
        ()
    | exception e ->
        failwith (Exn.to_string e)
end

(* Broadcast_pipe tests *)
module Broadcast_pipe_tests = struct
  (* Helper type for broadcast pipe tests *)
  type immediate_deferred_counter =
    { mutable immediate_iterations : int; mutable deferred_iterations : int }

  let test_listeners_receive_updates () =
    let expect_pipe t expected =
      let got_rev =
        Broadcast_pipe.Reader.fold t ~init:[] ~f:(fun acc a1 ->
            return (a1 :: acc) )
      in
      let%map got = got_rev >>| List.rev in
      Alcotest.(check (list int)) "Expected values from pipe match" expected got
    in

    let run_test () =
      let initial = 0 in
      let r, w = Broadcast_pipe.create initial in
      (* Initial value check *)
      Alcotest.(check int)
        "Initial value observed when peeking" initial
        (Broadcast_pipe.Reader.peek r) ;

      (* Setup listeners *)
      let d1 = expect_pipe r [ 0; 1; 2 ] in
      let d2 = expect_pipe r [ 0; 1; 2 ] in
      don't_wait_for d1 ;
      don't_wait_for d2 ;

      (* Write values *)
      let%bind () = Broadcast_pipe.Writer.write w 1 in
      let%bind () = Broadcast_pipe.Writer.write w 2 in

      (* Check latest value *)
      Alcotest.(check int)
        "Latest value is observed when peeking" 2
        (Broadcast_pipe.Reader.peek r) ;

      (* Close the pipe *)
      Broadcast_pipe.Writer.close w ;
      let%map _ = Deferred.both d1 d2 in
      ()
    in
    match Async.Thread_safe.block_on_async_exn run_test with
    | () ->
        ()
    | exception e ->
        failwith (Exn.to_string e)

  let test_writing_is_synchronous () =
    let run_test () =
      let pipe_r, pipe_w = Broadcast_pipe.create () in
      let counts1 = { immediate_iterations = 0; deferred_iterations = 0 }
      and counts2 = { immediate_iterations = 0; deferred_iterations = 0 } in

      let setup_reader counts =
        don't_wait_for
        @@ Broadcast_pipe.Reader.iter pipe_r ~f:(fun () ->
               counts.immediate_iterations <- counts.immediate_iterations + 1 ;
               let%map () = after @@ Time.Span.of_sec 1. in
               counts.deferred_iterations <- counts.deferred_iterations + 1 )
      in

      setup_reader counts1 ;
      (* The reader doesn't run until we yield *)
      Alcotest.(check int)
        "Initial immediate iterations" 0 counts1.immediate_iterations ;
      Alcotest.(check int)
        "Initial deferred iterations" 0 counts1.deferred_iterations ;

      (* After yielding, reader has run but not completed async work *)
      let%bind () = wait_for ~timeout:0.1 () in
      Alcotest.(check int)
        "Immediate iterations after first yield" 1 counts1.immediate_iterations ;
      Alcotest.(check int)
        "Deferred iterations after first yield" 0 counts1.deferred_iterations ;

      (* After yielding longer, deferred_iterations has been set *)
      let%bind () = wait_for ~timeout:1.1 () in
      Alcotest.(check int)
        "Immediate iterations after waiting" 1 counts1.immediate_iterations ;
      Alcotest.(check int)
        "Deferred iterations after waiting" 1 counts1.deferred_iterations ;

      (* Writing to the pipe blocks until the reader is finished *)
      let%bind () = Broadcast_pipe.Writer.write pipe_w () in
      Alcotest.(check int)
        "Immediate iterations after write" 2 counts1.immediate_iterations ;
      Alcotest.(check int)
        "Deferred iterations after write" 2 counts1.deferred_iterations ;

      (* A second reader gets the current value and all subsequent writes *)
      setup_reader counts2 ;
      Alcotest.(check int)
        "Second reader initial immediate iterations" 0
        counts2.immediate_iterations ;
      Alcotest.(check int)
        "Second reader initial deferred iterations" 0
        counts2.deferred_iterations ;

      let%bind () = wait_for ~timeout:0.1 () in
      Alcotest.(check int)
        "Second reader immediate iterations after yield" 1
        counts2.immediate_iterations ;
      Alcotest.(check int)
        "Second reader deferred iterations after yield" 0
        counts2.deferred_iterations ;

      let%bind () = Broadcast_pipe.Writer.write pipe_w () in
      Alcotest.(check int)
        "First reader immediate iterations after second write" 3
        counts1.immediate_iterations ;
      Alcotest.(check int)
        "First reader deferred iterations after second write" 3
        counts1.deferred_iterations ;
      Alcotest.(check int)
        "Second reader immediate iterations after second write" 2
        counts2.immediate_iterations ;
      Alcotest.(check int)
        "Second reader deferred iterations after second write" 2
        counts2.deferred_iterations ;

      return ()
    in
    match Async.Thread_safe.block_on_async_exn run_test with
    | () ->
        ()
    | exception e ->
        failwith (Exn.to_string e)
end

(* Register all the tests *)
let () =
  Alcotest.run "Pipe_lib tests"
    [ ( "Strict_pipe"
      , [ Alcotest.test_case "Close writer" `Quick
            Strict_pipe_tests.test_close_writer
        ; Alcotest.test_case "Close buffered writer" `Quick
            Strict_pipe_tests.test_close_buffered_writer
        ; Alcotest.test_case "Map closure" `Quick
            Strict_pipe_tests.test_map_closure
        ; Alcotest.test_case "Filter_map closure" `Quick
            Strict_pipe_tests.test_filter_map_closure
        ; Alcotest.test_case "Fork closure" `Quick
            Strict_pipe_tests.test_fork_closure
        ; Alcotest.test_case "Partition_map3 closure" `Quick
            Strict_pipe_tests.test_partition_map3_closure
        ; Alcotest.test_case "Transfer closure" `Quick
            Strict_pipe_tests.test_transfer_closure
        ; Alcotest.test_case "Merge iter filters closed pipes" `Quick
            Strict_pipe_tests.test_merge_iter_filters_closed_pipes
        ] )
    ; ( "Broadcast_pipe"
      , [ Alcotest.test_case "Listeners receive updates" `Quick
            Broadcast_pipe_tests.test_listeners_receive_updates
        ; Alcotest.test_case "Writing is synchronous" `Quick
            Broadcast_pipe_tests.test_writing_is_synchronous
        ] )
    ]
