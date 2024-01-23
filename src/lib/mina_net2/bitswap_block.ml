open Core_kernel

let or_error_list_bind ls ~f =
  let open Or_error.Let_syntax in
  let rec loop ls acc =
    let%bind acc' = acc in
    match ls with
    | [] ->
        return acc'
    | h :: t ->
        let%bind r = f h in
        loop t (return (r :: acc'))
  in
  loop ls (return []) >>| List.rev >>| List.concat

type link = Blake2.t

let link_size = Blake2.digest_size_in_bytes

let absolute_max_links_per_block = Stdint.Uint16.(to_int max_int)

(** A bitswap block schema consists of a series of branch-blocks and leaf-blocks.
 *  A branch-block contains both links to successive blocks, as well as data. A
 *  leaf-block contains only data, and no links. Of the branch-blocks, there will
 *  be either 0 or 1 block that has less links than the rest of the branch-blocks.
 *  We refer to this block as the partial-branch-block, and the other branch-blocks
 *  ar referred to as full-branch-blocks.
 *)
type schema =
  { num_total_blocks : int  (** the total number of blocks *)
  ; num_full_branch_blocks : int
        (** the number of link-blocks which contain the maximum number of links *)
  ; num_links_in_partial_branch_block : int
        (** the number of links in the non-full link block (if it is 0, there is no non-full link block *)
  ; last_leaf_block_data_size : int
        (** the size of data (in bytes) contained in the last block *)
  ; max_block_data_size : int
        (** the maximum data size (in bytes) that a block contains *)
  ; max_links_per_block : int
        (** the maximum number of links that can be stored in a block (all link-blocks except the non-full-link-block will have this number of links) *)
  }
[@@deriving compare, eq, sexp]

let required_bitswap_block_count ~max_block_size data_length =
  if data_length <= max_block_size - 2 then 1
  else
    let n1 = data_length - link_size in
    let n2 = max_block_size - link_size - 2 in
    (n1 + n2 - 1) / n2

let max_links_per_block ~max_block_size =
  let links_per_block = (max_block_size - 2) / link_size in
  min links_per_block absolute_max_links_per_block

let create_schema ~max_block_size data_length =
  let num_total_blocks =
    required_bitswap_block_count ~max_block_size data_length
  in
  let last_leaf_block_data_size =
    data_length - ((max_block_size - link_size - 2) * (num_total_blocks - 1))
  in
  let max_links_per_block = max_links_per_block ~max_block_size in
  let num_full_branch_blocks = (num_total_blocks - 1) / max_links_per_block in
  let num_links_in_partial_branch_block =
    num_total_blocks - 1 - (num_full_branch_blocks * max_links_per_block)
  in
  { num_total_blocks
  ; num_full_branch_blocks
  ; last_leaf_block_data_size
  ; num_links_in_partial_branch_block
  ; max_block_data_size = max_block_size
  ; max_links_per_block
  }

let create_schema_length_prefixed ~max_block_size data_length =
  create_schema ~max_block_size (data_length + 4)

let blocks_of_data ~max_block_size data =
  if max_block_size <= 2 + link_size then failwith "Max block size too small" ;
  let max_data_chunk_size = max_block_size - 2 in
  let data_length = Bigstring.length data in
  let schema = create_schema ~max_block_size data_length in
  let remaining_data = ref data_length in
  let blocks = Blake2.Table.create () in
  let link_queue = Queue.create () in
  let dequeue_chunk chunk_size =
    assert (!remaining_data >= chunk_size) ;
    let chunk =
      Bigstring.sub_shared data
        ~pos:(!remaining_data - chunk_size)
        ~len:chunk_size
    in
    remaining_data := !remaining_data - chunk_size ;
    chunk
  in
  let dequeue_links num_links =
    assert (Queue.length link_queue >= num_links) ;
    let links = ref [] in
    for _ = 1 to num_links do
      links := Queue.dequeue_exn link_queue :: !links
    done ;
    !links
  in
  let create_block links chunk_size =
    let chunk = dequeue_chunk chunk_size in
    let num_links = List.length links in
    let size = 2 + (num_links * link_size) + chunk_size in
    if num_links > absolute_max_links_per_block || size > max_block_size then
      failwith "invalid block produced" ;
    let block = Bigstring.create size in
    Bigstring.set_uint16_le_exn block ~pos:0 num_links ;
    List.iteri links ~f:(fun i link ->
        let link_buf = Bigstring.of_string (Blake2.to_raw_string link) in
        Bigstring.blit ~src:link_buf ~src_pos:0 ~dst:block
          ~dst_pos:(2 + (i * link_size))
          ~len:link_size ) ;
    Bigstring.blit ~src:chunk ~src_pos:0 ~dst:block
      ~dst_pos:(2 + (num_links * link_size))
      ~len:chunk_size ;
    let hash = Blake2.digest_bigstring block in
    Hashtbl.set blocks ~key:hash ~data:block ;
    Queue.enqueue link_queue hash
  in
  (* create the last block *)
  create_block [] schema.last_leaf_block_data_size ;
  if schema.num_total_blocks > 1 then (
    (* create the data-only blocks *)
    let num_data_only_blocks =
      schema.num_total_blocks - schema.num_full_branch_blocks - 1
      - if schema.num_links_in_partial_branch_block > 0 then 1 else 0
    in
    for _ = 1 to num_data_only_blocks do
      create_block [] max_data_chunk_size
    done ;
    (* create the non max link block, if there is one *)
    ( if schema.num_links_in_partial_branch_block > 0 then
      let chunk_size =
        max_block_size - 2
        - (schema.num_links_in_partial_branch_block * link_size)
      in
      create_block
        (dequeue_links schema.num_links_in_partial_branch_block)
        chunk_size ) ;
    (* create the max link blocks *)
    let full_link_chunk_size =
      max_block_size - 2 - (schema.max_links_per_block * link_size)
    in
    for _ = 1 to schema.num_full_branch_blocks do
      create_block
        (dequeue_links schema.max_links_per_block)
        full_link_chunk_size
    done ) ;
  assert (!remaining_data = 0) ;
  assert (Queue.length link_queue = 1) ;
  ( Blake2.Map.of_alist_exn (Hashtbl.to_alist blocks)
  , Queue.dequeue_exn link_queue )

let parse_block block =
  if Bigstring.length block < 2 then Or_error.error_string "block too short"
  else
    let num_links = Bigstring.get_uint16_le block ~pos:0 in
    if Bigstring.length block < 2 + (num_links * link_size) then
      Or_error.error_string "block has invalid number of links"
    else
      let links =
        List.init num_links ~f:(fun i ->
            block
            |> Bigstring.sub_shared ~pos:(2 + (i * link_size)) ~len:link_size
            |> Bigstring.to_string |> Blake2.of_raw_string )
      in
      let data =
        Bigstring.sub_shared block ~pos:(2 + (num_links * link_size))
      in
      Ok (links, data)

let data_of_blocks blocks root_hash =
  let links = Queue.of_list [ root_hash ] in
  let chunks = Queue.create () in
  let%map.Or_error () =
    with_return (fun { return } ->
        while Queue.length links > 0 do
          let hash = Queue.dequeue_exn links in
          let block =
            match Map.find blocks hash with
            | None ->
                return (Or_error.error_string "required block not found")
            | Some data ->
                data
          in
          let successive_links, chunk =
            match parse_block block with
            | Error error ->
                return (Error error)
            | Ok x ->
                x
          in
          List.iter successive_links ~f:(Queue.enqueue links) ;
          Queue.enqueue chunks chunk
        done ;
        Ok () )
  in
  let total_data_size = Queue.sum (module Int) chunks ~f:Bigstring.length in
  let data = Bigstring.create total_data_size in
  ignore
    ( Queue.fold chunks ~init:0 ~f:(fun dst_pos chunk ->
          Bigstring.blit ~src:chunk ~src_pos:0 ~dst:data ~dst_pos
            ~len:(Bigstring.length chunk) ;
          dst_pos + Bigstring.length chunk )
      : int ) ;
  data

let%test_module "bitswap blocks" =
  ( module struct
    let schema_of_blocks ~max_block_size blocks root_hash =
      let num_total_blocks = Map.length blocks in
      let num_full_branch_blocks = ref 0 in
      let num_links_in_partial_branch_block = ref None in
      let last_leaf_block_data_size = ref 0 in
      let max_links_per_block = max_links_per_block ~max_block_size in
      let rec crawl hash =
        let block = Map.find_exn blocks hash in
        let links, chunk = Or_error.ok_exn (parse_block block) in
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
                  "invalid blocks: only expected one outlying block with \
                   differing number of links"
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

    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let%bind max_block_size = Int.gen_uniform_incl 256 1024 in
      let%bind data_length = Int.gen_log_uniform_incl 1 (Int.pow 1024 2) in
      let%map data =
        String.gen_with_length data_length Char.quickcheck_generator
        >>| Bigstring.of_string
      in
      (max_block_size, data)

    let%test_unit "forall x: data_of_blocks (blocks_of_data x) = x" =
      Quickcheck.test gen ~trials:100 ~f:(fun (max_block_size, data) ->
          let blocks, root_block_hash = blocks_of_data ~max_block_size data in
          let result =
            Or_error.ok_exn (data_of_blocks blocks root_block_hash)
          in
          [%test_eq: Bigstring.t] data result )

    let%test_unit "forall x: schema_of_blocks (blocks_of_data x) = \
                   create_schema x" =
      Quickcheck.test gen ~trials:100 ~f:(fun (max_block_size, data) ->
          let schema = create_schema ~max_block_size (Bigstring.length data) in
          let blocks, root_block_hash = blocks_of_data ~max_block_size data in
          [%test_eq: schema] schema
            (schema_of_blocks ~max_block_size blocks root_block_hash) )

    let%test_unit "when x is aligned (has no partial branch block): \
                   data_of_blocks (blocks_of_data x) = x" =
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
      Out_channel.flush Out_channel.stdout ;
      [%test_eq: Bigstring.t] data result

    let with_libp2p_helper f =
      let open Async in
      let logger = Logger.null () in
      let pids = Pid.Table.create () in
      let handle_push_message _ = failwith "ama istimiyorum" in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind conf_dir = Unix.mkdtemp "bitswap_block_test" in
          let%bind helper =
            Libp2p_helper.spawn ~logger ~pids ~conf_dir ~handle_push_message
            >>| Or_error.ok_exn
          in
          Monitor.protect
            (fun () -> f helper)
            ~finally:(fun () ->
              let%bind () = Libp2p_helper.shutdown helper in
              File_system.remove_dir conf_dir ) )

    let%test_unit "forall x: libp2p_helper#decode (daemon#encode x) = x" =
      Quickcheck.test gen ~trials:100 ~f:(fun (max_block_size, data) ->
          let blocks, root_block_hash = blocks_of_data ~max_block_size data in
          let result =
            with_libp2p_helper (fun helper ->
                let open Libp2p_ipc.Rpcs in
                let request =
                  TestDecodeBitswapBlocks.create_request
                    ~blocks:
                      (blocks |> Map.map ~f:Bigstring.to_string |> Map.to_alist)
                    ~root_block_hash
                in
                Libp2p_helper.do_rpc helper
                  (module TestDecodeBitswapBlocks)
                  request )
            |> Or_error.ok_exn
            |> Libp2p_ipc.Reader.Libp2pHelperInterface.TestDecodeBitswapBlocks
               .Response
               .decoded_data_get |> Bigstring.of_string
          in
          [%test_eq: Bigstring.t] data result )

    let%test_unit "forall x: daemon#decode (libp2p_helper#encode x) = x" =
      Quickcheck.test gen ~trials:100 ~f:(fun (max_block_size, data) ->
          let blocks, root_block_hash =
            let resp =
              with_libp2p_helper (fun helper ->
                  let open Libp2p_ipc.Rpcs in
                  let request =
                    TestEncodeBitswapBlocks.create_request ~max_block_size
                      ~data:(Bigstring.to_string data)
                  in
                  Libp2p_helper.do_rpc helper
                    (module TestEncodeBitswapBlocks)
                    request )
              |> Or_error.ok_exn
            in
            let open Libp2p_ipc.Reader in
            let open Libp2pHelperInterface.TestEncodeBitswapBlocks in
            let blocks =
              Capnp.Array.map_list (Response.blocks_get resp)
                ~f:(fun block_with_id ->
                  let hash =
                    Blake2.of_raw_string
                    @@ BlockWithId.blake2b_hash_get block_with_id
                  in
                  let block =
                    Bigstring.of_string @@ BlockWithId.block_get block_with_id
                  in
                  (hash, block) )
            in
            let root_block_hash =
              Blake2.of_raw_string @@ RootBlockId.blake2b_hash_get
              @@ Response.root_block_id_get resp
            in
            (Blake2.Map.of_alist_exn blocks, root_block_hash)
          in
          let result =
            Or_error.ok_exn (data_of_blocks blocks root_block_hash)
          in
          [%test_eq: Bigstring.t] data result )
  end )
