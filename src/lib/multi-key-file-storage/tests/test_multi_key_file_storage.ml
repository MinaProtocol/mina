open Core_kernel
open Multi_key_file_storage

(* Helper to create temp file names *)
let temp_filename prefix = Core.Filename.temp_file prefix ".db"

(* Helper to clean up temp files *)
let cleanup_file filename = if Sys.file_exists filename then Sys.remove filename

(* Test basic write and read with a single value *)
let test_single_values () =
  let filename = temp_filename "single_value" in
  let int_value = 42 in
  let string_value = "hello world" in

  let int_tag, string_tag =
    write_values_exn
      ~f:(fun writer ->
        let int_tag = write_value writer (module Int) int_value in
        let string_tag = write_value writer (module String) string_value in
        (int_tag, string_tag) )
      filename
  in

  let int_result = read (module Int) int_tag |> Or_error.ok_exn in
  let string_result = read (module String) string_tag |> Or_error.ok_exn in
  cleanup_file filename ;

  Alcotest.(check int) "Single int value round-trip" int_value int_result ;
  Alcotest.(check string)
    "Single string value round-trip" string_value string_result

(* Test multiple values of the same type *)
let test_multiple_same_type () =
  let filename = temp_filename "multiple_same" in
  let original_values = [ 1; 2; 3; 42; 100; 999 ] in

  (* Write *)
  let tags =
    write_values_exn
      ~f:(fun writer ->
        List.map original_values ~f:(fun v ->
            write_value writer (module Int) v ) )
      filename
  in

  let results =
    List.map tags ~f:(fun tag -> read (module Int) tag |> Or_error.ok_exn)
  in
  cleanup_file filename ;

  Alcotest.(check (list int))
    "Multiple int values round-trip" original_values results

module Write_and_test_later = struct
  type read_and_check_t = { read_and_check : unit -> unit }

  let generic ~alcotest_check ~m value writer =
    let tag = write_value writer m value in
    { read_and_check =
        (fun () ->
          read m tag |> Or_error.ok_exn
          |> alcotest_check "Values do not match" value )
    }

  let int = generic ~alcotest_check:Alcotest.(check int) ~m:(module Int)

  let string = generic ~alcotest_check:Alcotest.(check string) ~m:(module String)

  let bool = generic ~alcotest_check:Alcotest.(check bool) ~m:(module Bool)

  let gen =
    let module Q = Base_quickcheck.Generator in
    match%bind.Q Q.of_list [ `Int; `String; `Bool ] with
    | `String ->
        Q.map ~f:string Q.string
    | `Int ->
        Q.map ~f:int Q.int
    | `Bool ->
        Q.map ~f:bool Q.bool
end

let triple gen =
  let module Q = Base_quickcheck.Generator in
  let%bind.Q gen1 = gen in
  let%bind.Q gen2 = gen in
  let%map.Q gen3 = gen in
  (gen1, gen2, gen3)

let expanded_read_ops_group =
  let module Q = Base_quickcheck.Generator in
  let%bind.Q group = Q.list_non_empty @@ Write_and_test_later.gen in
  let sz = List.length group in
  let%map.Q expansions = Q.list_with_length ~length:sz @@ Q.int_inclusive 1 4 in
  let expansions_total = List.sum (module Int) ~f:ident expansions in
  ( expansions_total
  , fun writer ->
      let read_ops = List.map ~f:(fun f -> f writer) group in
      List.concat_map
        ~f:(fun (n, op) -> List.init n ~f:(const op))
        (List.zip_exn expansions read_ops) )

let three_op_groups =
  let module Q = Base_quickcheck.Generator in
  let%bind.Q (sz1, group1), (sz2, group2), (sz3, group3) =
    triple expanded_read_ops_group
  in
  let%map.Q permutation =
    Q.list_permutations (List.init (sz1 + sz2 + sz3) ~f:ident)
  in
  fun (writer1, writer2, writer3) ->
    let read_ops =
      group1 writer1 @ group2 writer2 @ group3 writer3 |> Array.of_list
    in
    List.map permutation ~f:(fun i -> read_ops.(i))

(** Property test:
    Write three files with different write operations.
    Read the values back (some repeatedly) in a random order.
    Check that the values retrieved are correct. *)
let test_property () =
  let file1 = temp_filename "file1" in
  let file2 = temp_filename "file2" in
  let file3 = temp_filename "file3" in
  Quickcheck.test three_op_groups ~f:(fun write_three_groups ->
      let read_ops =
        write_values_exn file1 ~f:(fun writer1 ->
            write_values_exn file2 ~f:(fun writer2 ->
                write_values_exn file3 ~f:(fun writer3 ->
                    write_three_groups (writer1, writer2, writer3) ) ) )
      in
      List.iter read_ops ~f:(fun { Write_and_test_later.read_and_check } ->
          read_and_check () ) ) ;
  cleanup_file file1 ;
  cleanup_file file2 ;
  cleanup_file file3

(* Main test suite *)
let () =
  Alcotest.run "Multi_key_file_storage"
    [ ( "Basic operations"
      , [ Alcotest.test_case "Single value write/read" `Quick test_single_values
        ; Alcotest.test_case "Multiple same type" `Quick test_multiple_same_type
        ; Alcotest.test_case "Property test" `Quick test_property
        ] )
    ]
