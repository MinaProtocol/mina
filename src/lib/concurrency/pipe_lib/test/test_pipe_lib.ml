open Async_kernel
open Core_kernel

let read_all_values ~expected ?pipe iterator =
  let open Pipe_lib.Strict_pipe.Swappable in
  let counter = ref 0 in
  let expected_length = List.length expected in
  Iterator.iter iterator ~f:(fun x ->
      let expected_value = List.nth_exn expected !counter in
      counter := !counter + 1 ;
      if x <> expected_value then
        failwithf "unexpected read (expected: %d, got: %d)" expected_value x () ;
      if !counter = expected_length then Option.iter ~f:kill pipe ;
      return () )
  >>| fun () ->
  if !counter = expected_length then ()
  else
    failwithf "unexpected number of elements: expected %d, got %d"
      expected_length !counter ()

let create_buffered_swappable capacity =
  Pipe_lib.Strict_pipe.Swappable.create ~name:"swappable"
    (Buffered (`Capacity capacity, `Overflow (Drop_head (const ()))))

let read_all_values_or_timeout ?pipe ~expected iterator =
  let read_all_values = read_all_values iterator ~expected ?pipe in
  Deferred.choose
    [ Deferred.choice read_all_values ident
    ; Deferred.choice
        (after (Time_ns.Span.of_sec 1.5))
        (fun () -> failwith "Swappable strict pipe hangs, timeout!")
    ]

let test_reader_hang () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let swappable = create_buffered_swappable 5 in
  let%bind _hanging_reader = swap_reader swappable in
  write swappable 1 ;
  write swappable 2 ;
  let%bind good_reader = swap_reader swappable in
  write swappable 3 ;
  read_all_values_or_timeout good_reader ~pipe:swappable ~expected:[ 1; 2; 3 ]

let test_buffered_overflow () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let pipe = create_buffered_swappable 4 in
  (* Write 7 elements to a pipe with capacity 5, first 2 should be dropped due to overflow *)
  List.iter [ 1; 2; 3; 4; 5; 6; 7 ] ~f:(write pipe) ;
  let%bind reader = swap_reader pipe in
  (* It's unintuitive that 5 elements are returned when capacity is 4,
     but this is the behavior of strict pipe, i.e. there seems to be an
     off-by-one bug there. *)
  read_all_values_or_timeout ~pipe ~expected:[ 3; 4; 5; 6; 7 ] reader

let test_multiple_iterations () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let pipe = create_buffered_swappable 10 in
  let elements = [ 1; 2; 3; 4; 5 ] in
  (* Write elements to the pipe *)
  List.iter elements ~f:(write pipe) ;
  (* Get a reader and verify we can iterate twice *)
  let%bind reader = swap_reader pipe in
  (* First iteration *)
  let%bind () = read_all_values_or_timeout ~pipe ~expected:elements reader in
  (* Second iteration - should see the same elements again *)
  read_all_values_or_timeout ~expected:elements reader

let test_concurrent_iterators () =
  let open Pipe_lib.Strict_pipe.Swappable in
  let pipe = create_buffered_swappable 10 in

  (* Write initial two elements *)
  List.iter ~f:(write pipe) [ 1; 2 ] ;

  let%bind reader1 = swap_reader pipe in
  (* Run first iteration *)
  let%bind reader2 =
    let first_iter_count = ref 0 in
    let next_reader_ref = ref None in
    let%map () =
      Iterator.iter reader1 ~f:(fun _ ->
          incr first_iter_count ;
          if !first_iter_count = 2 then
            (* After reading two elements, create second iterator and write more elements *)
            let%map next_reader = swap_reader pipe in
            next_reader_ref := Some next_reader
          else return () )
    in
    (* Verify count *)
    if !first_iter_count <> 2 then
      failwithf "Unexpected read count for first iteration: %d"
        !first_iter_count () ;
    Option.value_exn !next_reader_ref
  in
  let%bind () =
    (* Repeat first iteration - should see the same elements again *)
    read_all_values_or_timeout ~expected:[ 1; 2 ] reader1
  in
  List.iter ~f:(write pipe) [ 3; 4; 5 ] ;
  let%bind () =
    read_all_values_or_timeout ~pipe ~expected:[ 3; 4; 5 ] reader2
  in
  (* Repeat second iteration - should see the same elements again *)
  read_all_values_or_timeout ~expected:[ 3; 4; 5 ] reader2

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Alcotest_async in
      run "Pipe_lib"
        [ ( "Strict_pipe.Swappable"
          , [ test_case "reader hangs" `Quick test_reader_hang
            ; test_case "buffered overflow drops head" `Quick
                test_buffered_overflow
            ; test_case "multiple iterations return same elements" `Quick
                test_multiple_iterations
            ; test_case "concurrent iterators read correct elements" `Quick
                test_concurrent_iterators
            ] )
        ] )
