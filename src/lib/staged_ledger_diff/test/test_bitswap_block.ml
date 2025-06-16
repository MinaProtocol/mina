(* Testing
   -------

   Component: Staged Ledger Diff / Bitswap Block
   Subject: Test bitswap block functionality
   Invocation: dune exec src/lib/staged_ledger_diff/test/test_bitswap_block.exe
*)

open Core_kernel
open Staged_ledger_diff.Bitswap_block

(* Re-export the schema_of_blocks function from the original test module *)
let schema_of_blocks ~max_block_size blocks root_hash =
  let num_total_blocks = Map.length blocks in
  let num_full_branch_blocks = ref 0 in
  let num_links_in_partial_branch_block = ref None in
  let last_leaf_block_data_size = ref 0 in
  let max_links_per_block = max_links_per_block ~max_block_size in
  let rec crawl hash =
    let block = Map.find_exn blocks hash in
    let links, chunk = Or_error.ok_exn (parse_block ~hash block) in
    ( match List.length links with
    | 0 ->
        let size = Bigstring.length chunk in
        last_leaf_block_data_size :=
          if !last_leaf_block_data_size = 0 then size
          else min !last_leaf_block_data_size size
    | n when n = max_links_per_block ->
        incr num_full_branch_blocks
    | n -> (
        match !num_links_in_partial_branch_block with
        | Some _ ->
            failwith
              "invalid blocks: only expected one outlying block with differing \
               number of links"
        | None ->
            num_links_in_partial_branch_block := Some n ) ) ;
    List.iter links ~f:crawl
  in
  crawl root_hash ;
  { num_total_blocks
  ; num_full_branch_blocks = !num_full_branch_blocks
  ; num_links_in_partial_branch_block =
      Option.value !num_links_in_partial_branch_block ~default:0
  ; last_leaf_block_data_size = !last_leaf_block_data_size
  ; max_block_data_size = max_block_size
  ; max_links_per_block
  }

let test_data_roundtrip () =
  Alcotest.(check unit)
    "forall x: data_of_blocks (blocks_of_data x) = x" ()
    (Quickcheck.test For_tests.gen ~trials:100 ~f:(fun (max_block_size, data) ->
         let blocks, root_block_hash = blocks_of_data ~max_block_size data in
         let result = Or_error.ok_exn (data_of_blocks blocks root_block_hash) in
         if not (Bigstring.equal data result) then
           failwithf "Data roundtrip failed: expected length %d, got length %d"
             (Bigstring.length data) (Bigstring.length result) () ) )

let test_schema_consistency () =
  Alcotest.(check unit)
    "forall x: schema_of_blocks (blocks_of_data x) = create_schema x" ()
    (Quickcheck.test For_tests.gen ~trials:100 ~f:(fun (max_block_size, data) ->
         let schema = create_schema ~max_block_size (Bigstring.length data) in
         let blocks, root_block_hash = blocks_of_data ~max_block_size data in
         let actual_schema =
           schema_of_blocks ~max_block_size blocks root_block_hash
         in
         if not (equal_schema schema actual_schema) then
           failwithf "Schema mismatch: expected %s, got %s"
             (Sexp.to_string_hum (sexp_of_schema schema))
             (Sexp.to_string_hum (sexp_of_schema actual_schema))
             () ) )

let test_aligned_data_roundtrip () =
  let max_block_size = 100 in
  let data_length = max_block_size * 10 in
  let data =
    Quickcheck.Generator.generate ~size:1
      ~random:(Splittable_random.State.of_int 0)
      (String.gen_with_length data_length Char.quickcheck_generator)
    |> Bigstring.of_string
  in
  assert (Bigstring.length data = data_length) ;
  let blocks, root_block_hash = blocks_of_data ~max_block_size data in
  let result = Or_error.ok_exn (data_of_blocks blocks root_block_hash) in
  Alcotest.(check unit)
    "when x is aligned (has no partial branch block): data_of_blocks \
     (blocks_of_data x) = x"
    ()
    ( if not (Bigstring.equal data result) then
      failwithf
        "Aligned data roundtrip failed: expected length %d, got length %d"
        (Bigstring.length data) (Bigstring.length result) () )

let () =
  let open Alcotest in
  run "Bitswap Block Tests"
    [ ( "Bitswap block functionality"
      , [ test_case "data roundtrip property" `Quick test_data_roundtrip
        ; test_case "schema consistency property" `Quick test_schema_consistency
        ; test_case "aligned data roundtrip" `Quick test_aligned_data_roundtrip
        ] )
    ]
