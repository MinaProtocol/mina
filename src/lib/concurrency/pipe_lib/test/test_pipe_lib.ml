open Async_kernel
open Core_kernel

let test_reader_hang () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let swappable =
    create ~name:"swappable"
      (Buffered (`Capacity 50, `Overflow (Drop_head (const ()))))
  in
  let%bind _hanging_reader = swap_reader swappable in
  write swappable 1 ;
  write swappable 2 ;
  let%bind good_reader = swap_reader swappable in
  write swappable 3 ;
  let read_all_values =
    let counter = ref 0 in
    Iterator.iter good_reader ~f:(fun x ->
        counter := !counter + 1 ;
        if x <> !counter then
          failwithf "unexpected read: broken order (expected: %d, got: %d)"
            !counter x () ;
        if !counter = 3 then kill swappable ;
        return () )
    >>| fun () ->
    if !counter = 3 then ()
    else failwithf "unexpected iter result: few elements, %d" !counter ()
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
