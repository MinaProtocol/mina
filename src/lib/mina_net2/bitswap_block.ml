open Core_kernel

let or_error_list_bind ls ~f =
  let open Or_error.Let_syntax in
  let rec loop = function
    | [] ->
        return []
    | h :: t ->
        let%bind r = f h in
        let%map t' = loop t in
        r :: t'
  in
  loop ls >>| List.concat

type link = Blake2.t

let link_size = Blake2.digest_size_in_bytes

let absolute_max_links_per_block = Stdint.Uint16.(to_int max_int)

type schema =
  { total_blocks : int
  ; full_link_blocks : int
  ; non_max_link_block_count : int
  ; last_block_data_size : int
  ; max_block_size : int
  ; max_links_per_block : int
  }
[@@deriving compare, eq, sexp]

let required_bitswap_block_count ~max_block_size data_length =
  if data_length <= max_block_size - 2 then 1
  else
    let n1 = data_length - link_size in
    let n2 = max_block_size - link_size - 2 in
    (n1 / n2) + if n1 mod n2 > 0 then 1 else 0

let max_links_per_block ~max_block_size =
  let links_per_block = (max_block_size - 2) / link_size in
  min links_per_block absolute_max_links_per_block

let create_schema ~max_block_size data_length =
  let total_blocks = required_bitswap_block_count ~max_block_size data_length in
  let last_block_data_size =
    data_length - ((max_block_size - link_size - 2) * (total_blocks - 1))
  in
  let max_links_per_block = max_links_per_block ~max_block_size in
  let non_max_link_block_count = (total_blocks - 1) mod max_links_per_block in
  let full_link_blocks = (total_blocks - 1) / max_links_per_block in
  { total_blocks
  ; last_block_data_size
  ; full_link_blocks
  ; non_max_link_block_count
  ; max_block_size
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
          ~len:link_size) ;
    Bigstring.blit ~src:chunk ~src_pos:0 ~dst:block
      ~dst_pos:(2 + (num_links * link_size))
      ~len:chunk_size ;
    let hash = Blake2.digest_bigstring block in
    Hashtbl.set blocks ~key:hash ~data:block ;
    Queue.enqueue link_queue hash
  in
  (* create the last block *)
  create_block [] schema.last_block_data_size ;
  if schema.total_blocks > 1 then (
    (* create the data-only blocks *)
    let num_data_only_blocks =
      schema.total_blocks - schema.full_link_blocks - 1
      - if schema.non_max_link_block_count > 0 then 1 else 0
    in
    for _ = 1 to num_data_only_blocks do
      create_block [] max_data_chunk_size
    done ;
    (* create the non max link block, if there is one *)
    if schema.non_max_link_block_count > 0 then (
      let chunk_size =
        max_block_size - 2 - (schema.non_max_link_block_count * link_size)
      in
      create_block (dequeue_links schema.non_max_link_block_count) chunk_size ;
      (* create the max link blocks *)
      let full_link_chunk_size =
        max_block_size - 2 - (schema.max_links_per_block * link_size)
      in
      for _ = 1 to schema.full_link_blocks do
        create_block
          (dequeue_links schema.max_links_per_block)
          full_link_chunk_size
      done ) ) ;
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
            |> Bigstring.to_string |> Blake2.of_raw_string)
      in
      let data =
        Bigstring.sub_shared block ~pos:(2 + (num_links * link_size))
      in
      Ok (links, data)

let data_of_blocks blocks root_hash =
  let open Or_error.Let_syntax in
  let rec parse_chunks hash =
    let%bind raw_block_data =
      match Map.find blocks hash with
      | Some data ->
          return data
      | None ->
          Or_error.error_string "required block not found"
    in
    let%bind links, data = parse_block raw_block_data in
    let%map tail = or_error_list_bind links ~f:parse_chunks in
    data :: tail
  in
  let%map chunks = parse_chunks root_hash in
  let total_data_size = List.sum (module Int) chunks ~f:Bigstring.length in
  let data = Bigstring.create total_data_size in
  ignore
    ( List.fold_left chunks ~init:0 ~f:(fun i chunk ->
          Bigstring.blit ~src:chunk ~src_pos:0 ~dst:data ~dst_pos:i
            ~len:(Bigstring.length chunk) ;
          i + Bigstring.length chunk)
      : int ) ;
  data

let%test_module "bitswap blocks" =
  ( module struct
    let schema_of_blocks ~max_block_size blocks root_hash =
      let total_blocks = Map.length blocks in
      let full_link_blocks = ref 0 in
      let non_max_link_block_count = ref None in
      let last_block_data_size = ref 0 in
      let max_links_per_block = max_links_per_block ~max_block_size in
      let rec crawl hash =
        let block = Map.find_exn blocks hash in
        let links, chunk = Or_error.ok_exn (parse_block block) in
        let num_links = List.length links in
        last_block_data_size := Bigstring.length chunk ;
        ( if num_links > 0 then
          if num_links = max_links_per_block then incr full_link_blocks
          else
            match !non_max_link_block_count with
            | Some _ ->
                failwith
                  "invalid blocks: only expected one outlying block with \
                   differing number of links"
            | None ->
                non_max_link_block_count := Some num_links ) ;
        List.iter links ~f:crawl
      in
      crawl root_hash ;
      { total_blocks
      ; full_link_blocks = !full_link_blocks
      ; non_max_link_block_count =
          Option.value !non_max_link_block_count ~default:0
      ; last_block_data_size = !last_block_data_size
      ; max_block_size
      ; max_links_per_block
      }

    let gen =
      let open Quickcheck.Generator in
      let gen_max_block_size = Int.gen_uniform_incl 256 (Int.pow 1024 2) in
      let gen_bigstring = String.quickcheck_generator >>| Bigstring.of_string in
      tuple2 gen_max_block_size gen_bigstring

    let%test_unit "forall x: data_of_blocks (blocks_of_data x) = x" =
      Quickcheck.test gen ~f:(fun (max_block_size, data) ->
          let blocks, root_block_hash = blocks_of_data ~max_block_size data in
          let result =
            Or_error.ok_exn (data_of_blocks blocks root_block_hash)
          in
          [%test_eq: Bigstring.t] data result)

    let%test_unit "forall x: schema_of_blocks (blocks_of_data x) = \
                   create_schema x" =
      Quickcheck.test gen ~f:(fun (max_block_size, data) ->
          let schema = create_schema ~max_block_size (Bigstring.length data) in
          let blocks, root_block_hash = blocks_of_data ~max_block_size data in
          [%test_eq: schema] schema
            (schema_of_blocks ~max_block_size blocks root_block_hash))
  end )
