open Async_kernel
open Core
open Mina_base
open Frontier_base
module Ledger_transfer = Ledger_transfer.Make (Ledger) (Ledger.Db)

let genesis_root_identifier ~genesis_state_hash =
  let open Root_identifier.Stable.Latest in
  {state_hash= genesis_state_hash}

let with_file ?size filename access_level ~f =
  let open Unix in
  let shared, mode =
    match access_level with
    | `Read ->
        (false, [O_RDONLY])
    | `Write ->
        (true, [O_RDWR; O_TRUNC; O_CREAT])
  in
  let fd = Unix.openfile filename ~mode in
  let buf_size =
    match size with
    | None ->
        Int64.to_int_exn Unix.(fstat fd).st_size
    | Some sz ->
        sz
  in
  let buf = Bigstring.map_file ~shared fd buf_size in
  let x = f buf in
  Bigstring.unsafe_destroy buf ;
  Unix.close fd ;
  x

module Locations = struct
  let snarked_ledger root = Filename.concat root "snarked_ledger"

  let tmp_snarked_ledger root = Filename.concat root "tmp_snarked_ledger"

  let potential_snarked_ledgers root =
    Filename.concat root "potential_snarked_ledgers.json"

  let potential_snarked_ledger root =
    let uuid = Uuid_unix.create () in
    Filename.concat root ("snarked_ledger" ^ Uuid.to_string_hum uuid)

  let root_identifier root = Filename.concat root "root"
end

(* TODO: create a reusable singleton factory abstraction *)
module rec Instance_type : sig
  type t =
    { snarked_ledger: Ledger.Db.t
    ; factory: Factory_type.t
    ; potential_snarked_ledgers: string Queue.t }
end =
  Instance_type

and Factory_type : sig
  type t =
    { directory: string
    ; logger: Logger.t
    ; mutable instance: Instance_type.t option
    ; ledger_depth: int }
end =
  Factory_type

open Instance_type
open Factory_type

module Instance = struct
  type t = Instance_type.t

  let potential_snarked_ledgers_to_yojson queue =
    `List
      (List.map (Queue.to_list queue) ~f:(fun filename -> `String filename))

  let potential_snarked_ledgers_of_yojson json =
    Yojson.Safe.Util.to_list json |> List.map ~f:Yojson.Safe.Util.to_string

  let write_potential_snarked_ledgers_to_disk t =
    Yojson.Safe.to_file
      (Locations.potential_snarked_ledgers t.factory.directory)
      (potential_snarked_ledgers_to_yojson t.potential_snarked_ledgers)

  let enqueue_snarked_ledger ~location t =
    Queue.enqueue t.potential_snarked_ledgers location ;
    write_potential_snarked_ledgers_to_disk t

  let dequeue_snarked_ledger t =
    let location = Queue.dequeue_exn t.potential_snarked_ledgers in
    File_system.rmrf location ;
    write_potential_snarked_ledgers_to_disk t

  let destroy_potential_snarked_ledgers potential_snarked_ledgers =
    List.iter (Queue.to_list potential_snarked_ledgers) ~f:File_system.rmrf

  let create factory =
    let potential_snarked_ledger_filenames_location =
      Locations.potential_snarked_ledgers factory.directory
    in
    let potential_snarked_ledgers =
      if Sys.file_exists potential_snarked_ledger_filenames_location = `Yes
      then
        let json =
          Yojson.Safe.from_file potential_snarked_ledger_filenames_location
        in
        Queue.of_list @@ potential_snarked_ledgers_of_yojson json
      else Queue.of_list []
    in
    let snarked_ledger =
      match Queue.dequeue potential_snarked_ledgers with
      | Some most_recent_snarked_ledger_filename ->
          let most_recent_snarked_ledger =
            Ledger.of_database
            @@ Ledger.Db.create ~depth:factory.ledger_depth
                 ~directory_name:most_recent_snarked_ledger_filename ()
          in
          let snarked_ledger =
            Ledger.Db.create ~depth:factory.ledger_depth
              ~directory_name:(Locations.tmp_snarked_ledger factory.directory)
              ()
          in
          ignore
          @@ Ledger_transfer.transfer_accounts ~src:most_recent_snarked_ledger
               ~dest:snarked_ledger ;
          File_system.rmrf @@ Locations.snarked_ledger factory.directory ;
          Sys.rename
            (Locations.tmp_snarked_ledger factory.directory)
            (Locations.snarked_ledger factory.directory) ;
          File_system.rmrf @@ most_recent_snarked_ledger_filename ;
          destroy_potential_snarked_ledgers potential_snarked_ledgers ;
          snarked_ledger
      | None ->
          Ledger.Db.create ~depth:factory.ledger_depth
            ~directory_name:(Locations.snarked_ledger factory.directory)
            ()
    in
    {snarked_ledger; factory; potential_snarked_ledgers= Queue.create ()}

  let destroy t =
    Ledger.Db.close t.snarked_ledger ;
    t.factory.instance <- None

  (* TODO: encapsulate functionality of snarked ledger *)
  let snarked_ledger {snarked_ledger; _} = snarked_ledger

  let set_root_identifier t new_root_identifier =
    [%log' trace t.factory.logger]
      ~metadata:
        [("root_identifier", Root_identifier.to_yojson new_root_identifier)]
      "Setting persistent root identifier" ;
    let size = Root_identifier.Stable.Latest.bin_size_t new_root_identifier in
    with_file (Locations.root_identifier t.factory.directory) `Write ~size
      ~f:(fun buf ->
        ignore
          (Root_identifier.Stable.Latest.bin_write_t buf ~pos:0
             new_root_identifier) )

  (* defaults to genesis *)
  let load_root_identifier t =
    let file = Locations.root_identifier t.factory.directory in
    match Unix.access file [`Exists; `Read] with
    | Error _ ->
        None
    | Ok () ->
        with_file file `Read ~f:(fun buf ->
            let root_identifier =
              Root_identifier.Stable.Latest.bin_read_t buf ~pos_ref:(ref 0)
            in
            [%log' trace t.factory.logger]
              ~metadata:
                [("root_identifier", Root_identifier.to_yojson root_identifier)]
              "Loaded persistent root identifier" ;
            Some root_identifier )

  let set_root_state_hash t state_hash = set_root_identifier t {state_hash}
end

type t = Factory_type.t

let create ~logger ~directory ~ledger_depth =
  {directory; logger; instance= None; ledger_depth}

let create_instance_exn t =
  assert (t.instance = None) ;
  let instance = Instance.create t in
  t.instance <- Some instance ;
  instance

let with_instance_exn t ~f =
  let instance = create_instance_exn t in
  let x = f instance in
  Instance.destroy instance ; x

let reset_to_genesis_exn t ~precomputed_values =
  let open Deferred.Let_syntax in
  assert (t.instance = None) ;
  let%map () = File_system.remove_dir t.directory in
  with_instance_exn t ~f:(fun instance ->
      ignore
        (Ledger_transfer.transfer_accounts
           ~src:
             (Lazy.force (Precomputed_values.genesis_ledger precomputed_values))
           ~dest:(Instance.snarked_ledger instance)) ;
      Instance.set_root_identifier instance
        (genesis_root_identifier
           ~genesis_state_hash:
             (Precomputed_values.genesis_state_hash precomputed_values)) )
