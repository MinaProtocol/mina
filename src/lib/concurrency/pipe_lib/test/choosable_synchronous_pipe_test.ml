open Core_kernel
open Async_kernel
open Pipe_lib.Choosable_synchronous_pipe

let write value pipe =
  Deferred.choose [ write_choice ~on_chosen:Fn.id pipe value ]

let expect_read_eof pipe =
  match%map read pipe with
  | `Eof ->
      ()
  | `Ok _ ->
      failwith "Unexpected value instead of EOF"

let expect_read expected pipe =
  match%map read pipe with
  | `Eof ->
      failwith "Unexpected EOF"
  | `Ok (v, pipe') when v = expected ->
      pipe'
  | `Ok (v, _) ->
      failwithf "Unexpected value: %d" v ()

let test_sync_pipe_close () =
  let reader, writer = create () in
  close writer ; expect_read_eof reader

let test_read_write_sequence () =
  let reader, writer = create () in
  don't_wait_for (write 42 writer >>= write 27 >>| close) ;
  let%bind reader' = expect_read 42 reader in
  let%bind reader'' = expect_read 27 reader' in
  expect_read_eof reader''

let test_write_after_close () =
  let reader, writer = create () in
  close writer ;
  let%bind _ = write 42 writer in
  expect_read_eof reader

let test_multiple_writes_on_same_pipe_closing_wrong_pipe () =
  let reader, writer = create () in
  let pending_write =
    let%bind _ = write 42 writer in
    write 27 writer >>| close
  in
  let%bind reader' = expect_read 42 reader in
  let%bind () = pending_write in
  Deferred.choose
    [ Deferred.choice (expect_read_eof reader') (fun _ ->
          failwith "Unexpected EOF" )
    ; Deferred.choice (after (Time_ns.Span.of_sec 0.5)) ident
    ]

let test_multiple_writes_on_same_pipe () =
  let reader, writer = create () in
  let pending_write =
    let%bind reader' = write 42 writer in
    let%map _ = write 27 writer in
    close reader'
  in
  let%bind reader' = expect_read 42 reader in
  let%bind () = pending_write in
  expect_read_eof reader'

let test_idempotent_read () =
  let reader, writer = create () in
  don't_wait_for (write 42 writer >>= write 27 >>| close) ;
  let%bind reader1 = expect_read 42 reader in
  let%bind reader2 = expect_read 42 reader in
  let%bind reader1' = expect_read 27 reader1 in
  let%bind reader2' = expect_read 27 reader2 in
  let%bind () = expect_read_eof reader1' in
  expect_read_eof reader2'

let sequential_write values pipe =
  Deferred.List.fold values ~init:pipe ~f:(Fn.flip write)

let sequential_expect_read values pipe =
  Deferred.List.fold values ~init:pipe ~f:(Fn.flip expect_read)

let test_sequential_read () =
  let reader, writer = create () in
  let values = [ 42; 27; 123; 456; 192 ] in
  don't_wait_for (sequential_write values writer >>| close) ;
  sequential_expect_read values reader >>= expect_read_eof

let test_iter () =
  let reader, writer = create () in
  let values = [ 42; 27; 123; 456; 192 ] in
  let values_rev = List.rev values in
  don't_wait_for (sequential_write values writer >>| close) ;
  let collected1 = ref [] in
  let collected2 = ref [] in
  let%bind () =
    iter reader ~f:(fun v ->
        collected1 := v :: !collected1 ;
        Deferred.unit )
  in
  let%bind () =
    iter reader ~f:(fun v ->
        collected2 := v :: !collected2 ;
        Deferred.unit )
  in
  assert (List.equal Int.equal values_rev !collected1) ;
  assert (List.equal Int.equal values_rev !collected2) ;
  sequential_expect_read values reader >>= expect_read_eof

let test_create_closed () = expect_read_eof (create_closed ())

let test_write_choice_selected () =
  let reader, writer = create () in
  let%map writer_opt =
    (* Writer will be selected before the 5s wait *)
    Deferred.choose
      [ write_choice ~on_chosen:Option.some writer 42
      ; Deferred.choice (after (Time_ns.Span.of_sec 5.0)) (const None)
      ]
  and _reader = expect_read 42 reader in
  assert (Option.is_some writer_opt)

let test_write_choice_not_selected () =
  let reader, writer = create () in
  let%bind n =
    (* Writer will not be selected before the 0.5s wait because there is no read *)
    Deferred.choose
      [ write_choice ~on_chosen:(const 57) writer 42
      ; Deferred.choice (after (Time_ns.Span.of_sec 0.5)) (const 78)
      ]
  in
  assert (n = 78) ;
  (* Checking that writing 101 followed by pipe closure
     after the writer-choice on 42 was not selected results
     in read of 101 followed by EOF *)
  don't_wait_for (write 101 writer >>| close) ;
  expect_read 101 reader >>= expect_read_eof

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Alcotest_async in
      run "Pipe_lib"
        [ ( "Choosable_synchronous_pipe"
          , [ test_case "close pipe" `Quick test_sync_pipe_close
            ; test_case "read/write sequence" `Quick test_read_write_sequence
            ; test_case "idempotent read" `Quick test_idempotent_read
            ; test_case "write after close" `Quick test_write_after_close
            ; test_case "multiple writes on same pipe" `Quick
                test_multiple_writes_on_same_pipe
            ; test_case
                "multiple writes on same pipe, closing wrong pipe, eof timeouts"
                `Quick test_multiple_writes_on_same_pipe_closing_wrong_pipe
            ; test_case "sequential read" `Quick test_sequential_read
            ; test_case "iterate pipe" `Quick test_iter
            ; test_case "create closed" `Quick test_create_closed
            ; test_case "write choice selected" `Quick
                test_write_choice_selected
            ; test_case "write choice not selected" `Quick
                test_write_choice_not_selected
            ] )
        ] )
