(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core_kernel

type opened_db_t =
  { (* statuses is a map from 32-byte key to a 1-byte value representing the status of a root bitswap block *)
    statuses : (Consensus.Body_reference.t, int, [ `Uni ]) Lmdb.Map.t
  ; blocks : (Blake2.t, Bigstring.t, [ `Uni ]) Lmdb.Map.t
  ; env : Lmdb.Env.t
  }

type t = { logger : Logger.t; dir : string; db : opened_db_t option ref }

module Root_block_status = struct
  type t = Partial | Full | Deleting [@@deriving enum]
end

let body_tag = Staged_ledger_diff.Body.Tag.(to_enum Body)

let full_status = Root_block_status.to_enum Full

let uint8_conv =
  Lmdb.Conv.make
    ~flags:Lmdb.Conv.Flags.(integer_key + integer_dup + dup_fixed)
    ~serialise:(fun alloc x ->
      let a = alloc 1 in
      Bigstring.set_uint8_exn a ~pos:0 x ;
      a )
    ~deserialise:(Bigstring.get_uint8 ~pos:0)
    ()

let blake2_conv =
  Lmdb.Conv.(
    make
      ~serialise:(fun alloc x ->
        let str = Blake2.to_raw_string x in
        serialise string alloc str )
      ~deserialise:(fun s -> deserialise string s |> Blake2.of_raw_string)
      ())

let open_db dir =
  if Sys.file_exists dir then
    try
      let env = Lmdb.Env.create ~max_maps:1 Ro dir in
      (* Env. *)
      let blocks =
        Lmdb.Map.open_existing ~key:blake2_conv ~value:Lmdb.Conv.bigstring Nodup
          env
      in
      let statuses =
        Lmdb.Map.open_existing ~key:blake2_conv ~value:uint8_conv ~name:"status"
          Nodup env
      in
      Some { blocks; statuses; env }
    with Lmdb.Error _ -> None
  else None

let mdb_map_resized = -30785

let with_db ~default ~f:unwrapped_f t =
  let rec f ({ env; _ } as db) =
    try unwrapped_f db
    with Lmdb.Error err_int as e ->
      if err_int = mdb_map_resized then (
        Lmdb.Env.set_map_size env 0 ;
        f db )
      else raise e
  in
  match !(t.db) with
  | Some db ->
      f db
  | None ->
      let db_opt = open_db t.dir in
      t.db := db_opt ;
      Option.value_map ~f ~default db_opt

let open_ ~logger dir = { logger; dir; db = ref None }

let get_status ({ logger; _ } as t) body_ref =
  with_db t ~default:None ~f:(fun { statuses; _ } ->
      try
        let raw_status = Lmdb.Map.get statuses body_ref in
        match Root_block_status.of_enum raw_status with
        | None ->
            [%log error] "Unexpected status $status for $body_reference"
              ~metadata:
                [ ("status", `Int raw_status)
                ; ("body_reference", Consensus.Body_reference.to_yojson body_ref)
                ] ;
            None
        | Some x ->
            Some x
      with Lmdb.Not_found -> None )

let read_body_impl blocks txn root_ref =
  let find_block ref =
    try Lmdb.Map.get ~txn blocks ref |> Some with Lmdb.Not_found -> None
  in
  let%bind.Or_error raw_root_block =
    Option.value_map
      ~f:(fun x -> Ok x)
      ~default:
        (Or_error.error_string
           (sprintf "root block %s not found" @@ Blake2.to_hex root_ref) )
      (find_block root_ref)
  in
  let%bind.Or_error root_links, root_data =
    Staged_ledger_diff.Bitswap_block.parse_block ~hash:root_ref raw_root_block
  in
  let%bind.Or_error () =
    if Bigstring.length root_data < 5 then
      Or_error.error_string
      @@ sprintf "Couldn't read root block for %s: data section is too short"
      @@ Consensus.Body_reference.to_hex root_ref
    else Ok ()
  in
  let len = Bigstring.get_uint32_le root_data ~pos:0 - 1 in
  let%bind.Or_error () =
    let raw_tag = Bigstring.get_uint8 root_data ~pos:4 in
    if body_tag = raw_tag then Ok ()
    else
      Or_error.error_string
      @@ sprintf "Unexpected tag %s for block %s" (Int.to_string raw_tag)
           (Consensus.Body_reference.to_hex root_ref)
  in
  let buf = Bigstring.create len in
  let pos = ref (Bigstring.length root_data - 5) in
  Bigstring.blit ~src:root_data ~src_pos:5 ~dst:buf ~dst_pos:0 ~len:!pos ;
  let q = Queue.create () in
  Queue.enqueue_all q root_links ;
  let%map.Or_error () =
    Staged_ledger_diff.Bitswap_block.iter_links q
      ~report_chunk:(fun data ->
        Bigstring.blit ~src:data ~src_pos:0 ~dst:buf ~dst_pos:!pos
          ~len:(Bigstring.length data) ;
        pos := !pos + Bigstring.length data )
      ~find_block
  in
  Staged_ledger_diff.Body.Stable.Latest.bin_read_t buf ~pos_ref:(ref 0)

let read_body ({ logger; _ } as t) body_ref =
  with_db t ~default:None ~f:(fun { statuses; blocks; env } ->
      let impl txn =
        try
          if Lmdb.Map.get ~txn statuses body_ref = full_status then (
            match read_body_impl blocks txn body_ref with
            | Ok r ->
                Some r
            | Error e ->
                [%log error]
                  "Couldn't read body for $body_reference with Full status: \
                   $error"
                  ~metadata:
                    [ ( "body_reference"
                      , Consensus.Body_reference.to_yojson body_ref )
                    ; ("error", `String (Error.to_string_hum e))
                    ] ;
                None )
          else None
        with Lmdb.Not_found -> None
      in
      match Lmdb.Txn.go Ro env impl with
      | None ->
          [%log error]
            "LMDB transaction failed unexpectedly while reading block \
             $body_reference"
            ~metadata:
              [ ("body_reference", Consensus.Body_reference.to_yojson body_ref)
              ] ;
          None
      | Some x ->
          x )

let%test_module "Block storage tests" =
  ( module struct
    open Full_frontier.For_tests
    open Async_kernel
    open Frontier_base

    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let logger = Logger.create ()

    let verifier = verifier ()

    let with_helper ~writer f =
      let handle_push_message _ msg =
        ( match msg with
        | Libp2p_ipc.Reader.DaemonInterface.PushMessage.ResourceUpdated m -> (
            let open Libp2p_ipc.Reader.DaemonInterface.ResourceUpdate in
            match (type_get m, ids_get_list m) with
            | Added, [ id_ ] ->
                let id = Libp2p_ipc.Reader.RootBlockId.blake2b_hash_get id_ in
                Pipe.write_without_pushback writer id
            | _ ->
                () )
        | _ ->
            () ) ;
        Deferred.unit
      in
      let open Mina_net2.For_tests in
      Helper.test_with_libp2p_helper ~logger ~handle_push_message
        (fun conf_dir helper ->
          let%bind me = generate_random_keypair helper in
          let maddr =
            multiaddr_to_libp2p_ipc
            @@ Mina_net2.Multiaddr.of_string "/ip4/127.0.0.1/tcp/12878"
          in
          let libp2p_config =
            Libp2p_ipc.create_libp2p_config
              ~private_key:(Mina_net2.Keypair.secret me)
              ~statedir:conf_dir ~listen_on:[ maddr ] ~external_multiaddr:maddr
              ~network_id:"s" ~unsafe_no_trust_ip:true ~flood:false
              ~direct_peers:[] ~seed_peers:[] ~known_private_ip_nets:[]
              ~peer_exchange:true ~peer_protection_ratio:0.2 ~min_connections:20
              ~max_connections:40 ~validation_queue_size:250
              ~gating_config:empty_libp2p_ipc_gating_config ?metrics_port:None
              ~topic_config:[] ()
          in
          let%bind _ =
            Helper.do_rpc helper
              (module Libp2p_ipc.Rpcs.Configure)
              (Libp2p_ipc.Rpcs.Configure.create_request ~libp2p_config)
            >>| Or_error.ok_exn
          in
          f conf_dir helper )

    let send_and_receive ~helper ~reader ~db breadcrumb =
      let body = Breadcrumb.block breadcrumb |> Mina_block.body in
      let body_ref = Staged_ledger_diff.Body.compute_reference body in
      let data =
        Staged_ledger_diff.Body.to_binio_bigstring body |> Bigstring.to_string
      in
      [%log info] "Sending add resource" ;
      Mina_net2.For_tests.Helper.send_add_resource
        ~tag:Staged_ledger_diff.Body.Tag.Body ~data helper ;
      [%log info] "Waiting for push message" ;
      let%map id_ = Pipe.read reader in
      let id = match id_ with `Ok a -> a | _ -> failwith "unexpected" in
      [%log info] "Push message received" ;
      [%test_eq: String.t] (Consensus.Body_reference.to_raw_string body_ref) id ;
      [%test_eq: Staged_ledger_diff.Body.t option] (Some body)
        (read_body db body_ref)

    let%test_unit "Write many blocks to reach mmap resize" =
      let n = 300 in
      Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:1
        ~f:(fun make_breadcrumb ->
          let frontier = create_frontier () in
          let root = Full_frontier.root frontier in
          let reader, writer = Pipe.create () in
          with_helper ~writer (fun conf_dir helper ->
              let db =
                open_ ~logger (String.concat ~sep:"/" [ conf_dir; "block-db" ])
              in
              let%bind () =
                make_breadcrumb root >>= send_and_receive ~db ~helper ~reader
              in
              Quickcheck.test
                (String.gen_with_length 1000000
                   Base_quickcheck.quickcheck_generator_char ) ~trials:n
                ~f:(fun data ->
                  Mina_net2.For_tests.Helper.send_add_resource
                    ~tag:Staged_ledger_diff.Body.Tag.Body ~data helper ) ;
              match%bind Pipe.read_exactly reader ~num_values:n with
              | `Exactly _ ->
                  make_breadcrumb root >>= send_and_receive ~db ~helper ~reader
              | _ ->
                  failwith "unexpected" ) ;
          clean_up_persistent_root ~frontier )

    let%test_unit "Write a block body to db and read it" =
      Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:4
        ~f:(fun make_breadcrumb ->
          let frontier = create_frontier () in
          let root = Full_frontier.root frontier in
          let reader, writer = Pipe.create () in
          with_helper ~writer (fun conf_dir helper ->
              let db =
                open_ ~logger (String.concat ~sep:"/" [ conf_dir; "block-db" ])
              in
              make_breadcrumb root >>= send_and_receive ~db ~helper ~reader ) ;
          clean_up_persistent_root ~frontier )
  end )
