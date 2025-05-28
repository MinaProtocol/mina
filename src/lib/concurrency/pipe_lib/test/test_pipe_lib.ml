open Async_kernel
open Core_kernel

let test_reader_hang () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let swappable =
    create ~name:"swappable"
      (Buffered (`Capacity 50, `Overflow (Drop_head (const ()))))
  in
  let%bind _hanging_reader =
    swap_reader ~reader_name:"hanging reader" swappable
  in
  write swappable 1 ;
  write swappable 2 ;
  let%bind good_reader = swap_reader ~reader_name:"good reader" swappable in
  write swappable 3 ;
  let read_all_values =
    Deferred.List.iter [ 1; 2; 3 ] ~f:(fun i ->
        match%map Iterator.read good_reader with
        | `Ok x when x = i ->
            ()
        | `Ok y ->
            failwithf "unexpected read: broken order (expected: %d, got: %d)" i
              y ()
        | `Eof ->
            failwith "unexpected read: EOF" )
  in
  Deferred.choose
    [ Deferred.choice read_all_values ident
    ; Deferred.choice
        (after (Time_ns.Span.of_sec 1.5))
        (fun () -> failwith "Swappable strict pipe hangs, timeout!")
    ]

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Alcotest_async in
      run "Pipe_lib"
        [ ( "Strict_pipe.Swappable"
          , [ Alcotest_async.test_case "reader hangs" `Quick test_reader_hang ]
          )
        ] )
