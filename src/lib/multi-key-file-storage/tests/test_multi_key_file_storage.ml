open Core_kernel
open Multi_key_file_storage

(* Helper to create temp file names *)
let temp_filename prefix = Core.Filename.temp_file prefix ".db"

(* Helper to clean up temp files *)
let cleanup_file filename =
  try if Sys.file_exists filename then Sys.remove filename with _exn -> ()

let simplest_test (type fkey) (module M : S with type filename_key = fkey)
    (filename_key : fkey) =
  let int_value = 42 in
  let string_value = "hello world" in

  let int_tag, string_tag =
    M.write_values_exn
      ~f:(fun writer ->
        let int_tag = M.write_value writer (module Int) int_value in
        let string_tag = M.write_value writer (module String) string_value in
        (int_tag, string_tag) )
      filename_key
  in

  let int_result = M.read (module Int) int_tag |> Or_error.ok_exn in
  let string_result = M.read (module String) string_tag |> Or_error.ok_exn in

  Alcotest.(check int) "Single int value round-trip" int_value int_result ;
  Alcotest.(check string)
    "Single string value round-trip" string_value string_result

(* Test basic write and read with a single value *)
let test_single_values () =
  let filename = temp_filename "single_value" in
  let res =
    Or_error.try_with
    @@ fun () -> simplest_test (module Multi_key_file_storage) filename
  in
  cleanup_file filename ; Or_error.ok_exn res

(* Test multiple values of the same type *)
let test_multiple_same_type () =
  let filename = temp_filename "multiple_same" in
  let original_values = [ 1; 2; 3; 42; 100; 999 ] in

  let res =
    Or_error.try_with
    @@ fun () ->
    let tags =
      write_values_exn
        ~f:(fun writer ->
          List.map original_values ~f:(fun v ->
              write_value writer (module Int) v ) )
        filename
    in
    List.map tags ~f:(fun tag -> read (module Int) tag |> Or_error.ok_exn)
  in
  cleanup_file filename ;
  Or_error.ok_exn res
  |> Alcotest.(check (list int))
       "Multiple int values round-trip" original_values

let test_custom_filename_key () =
  let filename x = Data_hash_lib.State_hash.to_decimal_string x ^ ".dat" in
  let state_hash : Data_hash_lib.State_hash.t =
    Base_quickcheck.Generator.generate Data_hash_lib.State_hash.gen ~size:1
      ~random:(Splittable_random.State.create Random.State.default)
  in
  let module M = Make_custom (struct
    type filename_key = Data_hash_lib.State_hash.t

    let filename = filename
  end) in
  let res =
    Or_error.try_with @@ fun () -> simplest_test (module M) state_hash
  in
  cleanup_file (filename state_hash) ;
  Or_error.ok_exn res

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

let expanded_read_ops_group ?length () =
  let module Q = Base_quickcheck.Generator in
  let list_gen =
    Option.value_map length ~default:Q.list_non_empty ~f:(fun length ->
        Q.list_with_length ~length )
  in
  let%bind.Q group = list_gen Write_and_test_later.gen in
  let sz = List.length group in
  let%map.Q expansions = Q.list_with_length ~length:sz @@ Q.int_inclusive 1 4 in
  let expansions_total = List.sum (module Int) ~f:ident expansions in
  ( expansions_total
  , fun writer ->
      let read_ops = List.map ~f:(fun f -> f writer) group in
      List.concat_map
        ~f:(fun (n, op) -> List.init n ~f:(const op))
        (List.zip_exn expansions read_ops) )

let three_op_groups ?length () =
  let module Q = Base_quickcheck.Generator in
  let%bind.Q (sz1, group1), (sz2, group2), (sz3, group3) =
    triple (expanded_read_ops_group ?length ())
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
let test_property ?length () =
  let file1 = temp_filename "file1" in
  let file2 = temp_filename "file2" in
  let file3 = temp_filename "file3" in
  let res =
    Or_error.try_with
    @@ fun () ->
    Quickcheck.test (three_op_groups ?length ()) ~f:(fun write_three_groups ->
        let read_ops =
          write_values_exn file1 ~f:(fun writer1 ->
              write_values_exn file2 ~f:(fun writer2 ->
                  write_values_exn file3 ~f:(fun writer3 ->
                      write_three_groups (writer1, writer2, writer3) ) ) )
        in
        List.iter read_ops ~f:(fun { Write_and_test_later.read_and_check } ->
            read_and_check () ) )
  in
  cleanup_file file1 ;
  cleanup_file file2 ;
  cleanup_file file3 ;
  Or_error.ok_exn res

(* Main test suite *)
let () =
  Alcotest.run "Multi_key_file_storage"
    [ ( "Basic operations"
      , [ Alcotest.test_case "Single value write/read" `Quick test_single_values
        ; Alcotest.test_case "Multiple same type" `Quick test_multiple_same_type
        ; Alcotest.test_case "Custom filename key" `Quick
            test_custom_filename_key
        ; Alcotest.test_case "Property test" `Quick (test_property ?length:None)
        ; Alcotest.test_case "Property test (big lists)" `Quick
            (test_property ~length:64000)
        ] )
    ]
