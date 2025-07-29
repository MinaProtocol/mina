open Core
open Mina_base
module Ledger = Mina_ledger.Ledger
open Frontier_base
module Ledger_transfer = Mina_ledger.Ledger_transfer.Make (Ledger) (Ledger.Db)
module Ledger_transfer_stable =
  Mina_ledger.Ledger_transfer.Make (Ledger.Db) (Ledger.Db)

let transfer_snarked_root =
  Ledger.Root.transfer_accounts_with
    ~stable:Ledger_transfer_stable.transfer_accounts

let genesis_root_identifier ~genesis_state_hash =
  let open Root_identifier.Stable.Latest in
  { state_hash = genesis_state_hash }

let with_file ?size filename access_level ~f =
  let open Unix in
  let shared, mode =
    match access_level with
    | `Read ->
        (false, [ O_RDONLY ])
    | `Write ->
        (true, [ O_RDWR; O_TRUNC; O_CREAT ])
  in
  let fd = Unix.openfile filename ~mode in
  let buf_size =
    match size with
    | None ->
        Int64.to_int_exn Unix.(fstat fd).st_size
    | Some sz ->
        sz
  in
  (* Bigstring.map_file has been removed. We copy its old implementation. *)
  let buf =
    Bigarray.(
      array1_of_genarray
        (Core.Unix.map_file fd char c_layout ~shared [| buf_size |]))
  in
  let x = f buf in
  Bigstring.unsafe_destroy buf ;
  Unix.close fd ;
  x

module Locations = struct
  let snarked_ledger root = Filename.concat root "snarked_ledger"

  let tmp_snarked_ledger root = Filename.concat root "tmp_snarked_ledger"

  (** potential_snarked_ledgers is a json file that stores a list of potential
      snarked ledgeres *)
  let potential_snarked_ledgers root =
    Filename.concat root "potential_snarked_ledgers.json"

  (** potential_snarked_ledger is the actual location of each potential snarked
      ledger *)
  let potential_snarked_ledger root =
    let uuid = Uuid_unix.create () in
    Filename.concat root ("snarked_ledger" ^ Uuid.to_string_hum uuid)

  let root_identifier root = Filename.concat root "root"
end

(* TODO: create a reusable singleton factory abstraction *)
module rec Instance_type : sig
  type t =
    { snarked_ledger : Ledger.Root.t
    ; migrated_root : Ledger.Db.t option
    ; potential_snarked_ledgers : string Queue.t
    ; factory : Factory_type.t
    }
end =
  Instance_type

and Factory_type : sig
  type t =
    { directory : string
    ; migrated_dir : string option
    ; logger : Logger.t
    ; mutable instance : Instance_type.t option
    ; ledger_depth : int
    }
end =
  Factory_type

open Instance_type
open Factory_type

module Instance = struct
  type t = Instance_type.t

  let potential_snarked_ledgers_to_yojson queue =
    `List (List.map (Queue.to_list queue) ~f:(fun filename -> `String filename))

  let potential_snarked_ledgers_of_yojson json =
    Yojson.Safe.Util.to_list json |> List.map ~f:Yojson.Safe.Util.to_string

  let load_potential_snarked_ledgers_from_disk factory =
    let location = Locations.potential_snarked_ledgers factory.directory in
    if phys_equal (Sys.file_exists location) `Yes then
      Yojson.Safe.from_file location |> potential_snarked_ledgers_of_yojson
    else []

  let write_potential_snarked_ledgers_to_disk t =
    Yojson.Safe.to_file
      (Locations.potential_snarked_ledgers t.factory.directory)
      (potential_snarked_ledgers_to_yojson t.potential_snarked_ledgers)

  let enqueue_snarked_ledger ~location t =
    Queue.enqueue t.potential_snarked_ledgers location ;
    write_potential_snarked_ledgers_to_disk t

  let dequeue_snarked_ledger t =
    let location = Queue.dequeue_exn t.potential_snarked_ledgers in
    Mina_stdlib_unix.File_system.rmrf location ;
    write_potential_snarked_ledgers_to_disk t

  let destroy t =
    List.iter
      (Queue.to_list t.potential_snarked_ledgers)
      ~f:Mina_stdlib_unix.File_system.rmrf ;
    Mina_stdlib_unix.File_system.rmrf
      (Locations.potential_snarked_ledgers t.factory.directory) ;
    Ledger.Root.close t.snarked_ledger ;
    t.factory.instance <- None

  let close t =
    Ledger.Root.close t.snarked_ledger ;
    t.factory.instance <- None

  let migrate_root ~logger ~source factory =
    let%bind.Option migrated_dir = factory.migrated_dir in
    let migrated_db =
      Ledger.Db.create ~directory_name:migrated_dir ~fresh:true
        ~depth:factory.ledger_depth ()
    in
    [%log info] "Transfering all account to migrated root"
      ~metadata:
        [ ("source", `String factory.directory)
        ; ("migrated_dir", `String migrated_dir)
        ] ;
    match Ledger_transfer.transfer_accounts ~src:source ~dest:migrated_db with
    | Ok migrated_db ->
        [%log info] "Succesfully migrated root"
          ~metadata:[ ("migrated_dir", `String migrated_dir) ] ;
        Some migrated_db
    | Error reason ->
        [%log info] "Failed to miragte root"
          ~metadata:
            [ ("migrated_dir", `String migrated_dir)
            ; ("reason", `String (Error.to_string_hum reason))
            ] ;
        None

  let create ~logger factory =
    let snarked_ledger =
      Ledger.Root.create_single ~depth:factory.ledger_depth
        ~directory_name:(Locations.snarked_ledger factory.directory)
        ()
    in
    let migrated_root =
      migrate_root
        ~source:(Ledger.Root.as_masked snarked_ledger)
        ~logger factory
    in
    { snarked_ledger
    ; migrated_root
    ; potential_snarked_ledgers = Queue.create ()
    ; factory
    }

  (** When we load from disk,
      1. Check the potential_snarked_ledgers to see if any one of these
         matches the snarked_ledger_hash in persistent_frontier;
      2. if none of those works, we load the old snarked_ledger and check if
         the old snarked_ledger matches with persistent_frontier;
      3. if not, we just reset all the persisted data and start from genesis
   *)
  let load_from_disk factory ~snarked_ledger_hash ~logger =
    let potential_snarked_ledgers =
      load_potential_snarked_ledgers_from_disk factory
    in
    let snarked_ledger =
      List.fold_until potential_snarked_ledgers ~init:None
        ~f:(fun _ location ->
          let potential_snarked_ledger =
            Ledger.Root.create_single ~depth:factory.ledger_depth
              ~directory_name:location ()
          in
          let potential_snarked_ledger_hash =
            Frozen_ledger_hash.of_ledger_hash
            @@ Ledger.Root.merkle_root potential_snarked_ledger
          in
          [%log debug]
            ~metadata:
              [ ( "potential_snarked_ledger_hash"
                , Frozen_ledger_hash.to_yojson potential_snarked_ledger_hash )
              ]
            "loaded potential_snarked_ledger from disk" ;
          if
            Frozen_ledger_hash.equal potential_snarked_ledger_hash
              snarked_ledger_hash
          then (
            let snarked_ledger =
              Ledger.Root.create_single ~depth:factory.ledger_depth
                ~directory_name:(Locations.tmp_snarked_ledger factory.directory)
                ()
            in
            match
              transfer_snarked_root ~src:potential_snarked_ledger
                ~dest:snarked_ledger
            with
            | Ok _ ->
                Ledger.Root.close potential_snarked_ledger ;
                Mina_stdlib_unix.File_system.rmrf
                @@ Locations.snarked_ledger factory.directory ;
                Sys.rename
                  (Locations.tmp_snarked_ledger factory.directory)
                  (Locations.snarked_ledger factory.directory) ;
                List.iter potential_snarked_ledgers
                  ~f:Mina_stdlib_unix.File_system.rmrf ;
                Mina_stdlib_unix.File_system.rmrf
                  (Locations.potential_snarked_ledgers factory.directory) ;
                Stop (Some snarked_ledger)
            | Error e ->
                Ledger.Root.close potential_snarked_ledger ;
                List.iter potential_snarked_ledgers
                  ~f:Mina_stdlib_unix.File_system.rmrf ;
                Mina_stdlib_unix.File_system.rmrf
                  (Locations.potential_snarked_ledgers factory.directory) ;
                [%log' error factory.logger]
                  ~metadata:[ ("error", `String (Error.to_string_hum e)) ]
                  "Ledger_transfer failed" ;
                Stop None )
          else (
            Ledger.Root.close potential_snarked_ledger ;
            Continue None ) )
        ~finish:(fun _ ->
          List.iter potential_snarked_ledgers
            ~f:Mina_stdlib_unix.File_system.rmrf ;
          Mina_stdlib_unix.File_system.rmrf
            (Locations.potential_snarked_ledgers factory.directory) ;
          None )
    in
    match snarked_ledger with
    | None ->
        let snarked_ledger =
          Ledger.Root.create_single ~depth:factory.ledger_depth
            ~directory_name:(Locations.snarked_ledger factory.directory)
            ()
        in
        let potential_snarked_ledger_hash =
          Frozen_ledger_hash.of_ledger_hash
          @@ Ledger.Root.merkle_root snarked_ledger
        in
        if
          Frozen_ledger_hash.equal potential_snarked_ledger_hash
            snarked_ledger_hash
        then Ok (create ~logger factory)
        else (
          Ledger.Root.close snarked_ledger ;
          Error `Snarked_ledger_mismatch )
    | Some snarked_ledger ->
        let migrated_root =
          migrate_root ~logger
            ~source:(Ledger.Root.as_masked snarked_ledger)
            factory
        in
        Ok
          { snarked_ledger
          ; migrated_root
          ; potential_snarked_ledgers = Queue.create ()
          ; factory
          }

  let snarked_ledger { snarked_ledger; _ } = snarked_ledger

  let set_root_identifier t new_root_identifier =
    [%log' trace t.factory.logger]
      ~metadata:
        [ ("root_identifier", Root_identifier.to_yojson new_root_identifier) ]
      "Setting persistent root identifier" ;
    let size = Root_identifier.Stable.Latest.bin_size_t new_root_identifier in
    with_file (Locations.root_identifier t.factory.directory) `Write ~size
      ~f:(fun buf ->
        ignore
          ( Root_identifier.Stable.Latest.bin_write_t buf ~pos:0
              new_root_identifier
            : int ) )

  (* defaults to genesis *)
  let load_root_identifier t =
    let file = Locations.root_identifier t.factory.directory in
    match Unix.access file [ `Exists; `Read ] with
    | Error _ ->
        None
    | Ok () ->
        with_file file `Read ~f:(fun buf ->
            let root_identifier =
              Root_identifier.Stable.Latest.bin_read_t buf ~pos_ref:(ref 0)
            in
            [%log' trace t.factory.logger]
              ~metadata:
                [ ("root_identifier", Root_identifier.to_yojson root_identifier)
                ]
              "Loaded persistent root identifier" ;
            Some root_identifier )

  let set_root_state_hash t state_hash = set_root_identifier t { state_hash }
end

type t = Factory_type.t

let create ?migrated_dir ~logger ~directory ~ledger_depth () =
  { directory; migrated_dir; logger; instance = None; ledger_depth }

let create_instance_exn ~logger t =
  assert (Option.is_none t.instance) ;
  let instance = Instance.create ~logger t in
  t.instance <- Some instance ;
  instance

let load_from_disk_exn t ~snarked_ledger_hash ~logger =
  let open Result.Let_syntax in
  assert (Option.is_none t.instance) ;
  let%map instance = Instance.load_from_disk t ~snarked_ledger_hash ~logger in
  t.instance <- Some instance ;
  instance

let with_instance_exn t ~f ~logger =
  let instance = create_instance_exn ~logger t in
  let x = f instance in
  Instance.close instance ; x

let reset_to_genesis_exn t ~precomputed_values =
  assert (Option.is_none t.instance) ;
  Mina_stdlib_unix.File_system.rmrf t.directory ;
  with_instance_exn t ~f:(fun instance ->
      ignore
        ( Precomputed_values.populate_root precomputed_values
            (Instance.snarked_ledger instance)
          |> Or_error.map ~f:Ledger.Root.as_unmasked
          : Ledger.Any_ledger.witness Or_error.t ) ;
      Instance.set_root_identifier instance
        (genesis_root_identifier
           ~genesis_state_hash:
             (Precomputed_values.genesis_state_hashes precomputed_values)
               .state_hash ) )
