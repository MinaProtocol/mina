open Async_kernel
open Core_kernel

let read_all_values iterator ~expected ~pipe =
  let open Pipe_lib.Strict_pipe.Swappable in
  let counter = ref 0 in
  let expected_length = List.length expected in
  Iterator.iter iterator ~f:(fun x ->
      let expected_value = List.nth_exn expected !counter in
      counter := !counter + 1 ;
      if x <> expected_value then
        failwithf "unexpected read (expected: %d, got: %d)" expected_value x () ;
      if !counter = expected_length then kill pipe ;
      return () )
  >>| fun () ->
  if !counter = expected_length then ()
  else
    failwithf "unexpected number of elements: expected %d, got %d"
      expected_length !counter ()

let create_buffered_swappable () =
  Pipe_lib.Strict_pipe.Swappable.create ~name:"swappable"
    (Buffered (`Capacity 50, `Overflow (Drop_head (const ()))))

let read_all_values_or_timeout iterator ~pipe ~expected =
  let read_all_values = read_all_values iterator ~expected ~pipe in
  Deferred.choose
    [ Deferred.choice read_all_values ident
    ; Deferred.choice
        (after (Time_ns.Span.of_sec 1.5))
        (fun () -> failwith "Swappable strict pipe hangs, timeout!")
    ]

let test_reader_hang () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let swappable = create_buffered_swappable () in
  let%bind _hanging_reader = swap_reader swappable in
  write swappable 1 ;
  write swappable 2 ;
  let%bind good_reader = swap_reader swappable in
  write swappable 3 ;
  read_all_values_or_timeout good_reader ~pipe:swappable ~expected:[ 1; 2; 3 ]

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Alcotest_async in
      run "Pipe_lib"
        [ ( "Strict_pipe.Swappable"
          , [ Alcotest_async.test_case "reader hangs" `Quick test_reader_hang ]
          )
        ] )
