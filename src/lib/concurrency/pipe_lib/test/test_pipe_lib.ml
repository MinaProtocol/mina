open Async
open Core_kernel
open Pipe_lib

let test_reader_hang () =
  let swappable =
    Strict_pipe.Swappable.create ~name:"swappable"
      (Buffered (`Capacity 50, `Overflow (Drop_head (const ()))))
  in
  let%bind _hanging_reader =
    Strict_pipe.Swappable.swap_reader ~reader_name:"hanging reader" swappable
  in
  Strict_pipe.Swappable.write swappable 1 ;
  Strict_pipe.Swappable.write swappable 2 ;
  let%bind good_reader =
    Strict_pipe.Swappable.swap_reader ~reader_name:"good reader" swappable
  in
  Strict_pipe.Swappable.write swappable 3 ;
  let read_all_values =
    Deferred.List.iter [ 1; 2; 3 ] ~f:(fun i ->
        match%map Strict_pipe.Swappable.Iterator.read good_reader with
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
        (after (Time.Span.of_sec 1.5))
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
