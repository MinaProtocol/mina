(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
open Core_kernel

module F (Db : Generic.Db) = struct
  type holder =
    { statuses : (Consensus.Body_reference.t, int) Db.t
    ; blocks : (Blake2.t, Bigstring.t) Db.t
    }

  let mk_maps { Db.create } =
    let open Conv in
    let blocks = create blake2 Lmdb.Conv.bigstring in
    let statuses = create blake2 uint8 ~name:"status" in
    { statuses; blocks }

  let config = { Generic.default_config with initial_mmap_size = 256 lsl 20 }
end

module Storage = Generic.Read_only (F)

type t = Storage.t * Storage.holder

module Root_block_status = struct
  type t = Partial | Full | Deleting [@@deriving enum, equal]
end

let body_tag = Mina_net2.Bitswap_tag.(to_enum Body)

let full_status = Root_block_status.to_enum Full

let create = Storage.create

let get_status ~logger ((env, { statuses; _ }) : t) body_ref =
  let%bind.Option raw_status = Storage.get ~env statuses body_ref in
  let res = Root_block_status.of_enum raw_status in
  if Option.is_none res then
    [%log error] "Unexpected status $status for $body_reference"
      ~metadata:
        [ ("status", `Int raw_status)
        ; ("body_reference", Consensus.Body_reference.to_yojson body_ref)
        ] ;
  res

let read_body_impl find_block root_ref =
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

let read_body ((env, { statuses; blocks }) : t) body_ref =
  Storage.with_txn env ~f:(fun { get; _ } ->
      if Option.equal Int.equal (get statuses body_ref) (Some full_status) then
        read_body_impl (get blocks) body_ref
        |> Result.map_error ~f:(fun e -> `Invalid_structure e)
      else Error `Non_full )
  |> function None -> Error `Tx_failed | Some res -> res

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
      let body_ref =
        Staged_ledger_diff.Body.compute_reference
          ~tag:Mina_net2.Bitswap_tag.(to_enum Body)
          body
      in
      let data =
        Staged_ledger_diff.Body.to_binio_bigstring body |> Bigstring.to_string
      in
      [%log info] "Sending add resource" ;
      Mina_net2.For_tests.Helper.send_add_resource
        ~tag:Mina_net2.Bitswap_tag.Body ~data helper ;
      [%log info] "Waiting for push message" ;
      let%map id_ = Pipe.read reader in
      let id = match id_ with `Ok a -> a | _ -> failwith "unexpected" in
      [%log info] "Push message received" ;
      [%test_eq: String.t] (Consensus.Body_reference.to_raw_string body_ref) id ;
      [%test_eq:
        ( Mina_block.Body.t
        , [ `Invalid_structure of Error.t | `Non_full | `Tx_failed ] )
        Result.t] (Ok body) (read_body db body_ref)

    let%test_unit "Write many blocks" =
      let n = 300 in
      Quickcheck.test (gen_breadcrumb ~verifier ()) ~trials:1
        ~f:(fun make_breadcrumb ->
          let frontier = create_frontier () in
          let root = Full_frontier.root frontier in
          let reader, writer = Pipe.create () in
          with_helper ~writer (fun conf_dir helper ->
              let db =
                create (String.concat ~sep:"/" [ conf_dir; "block-db" ])
              in
              let%bind () =
                make_breadcrumb root >>= send_and_receive ~db ~helper ~reader
              in
              Quickcheck.test
                (String.gen_with_length 1000
                   (* increase to 1000000 to reach past mmap size of 256 MiB*)
                   Base_quickcheck.quickcheck_generator_char ) ~trials:n
                ~f:(fun data ->
                  Mina_net2.For_tests.Helper.send_add_resource
                    ~tag:Mina_net2.Bitswap_tag.Body ~data helper ) ;
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
                create (String.concat ~sep:"/" [ conf_dir; "block-db" ])
              in
              make_breadcrumb root >>= send_and_receive ~db ~helper ~reader ) ;
          clean_up_persistent_root ~frontier )
  end )
