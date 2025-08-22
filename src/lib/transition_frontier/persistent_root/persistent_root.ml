open Core
open Mina_base
module Ledger = Mina_ledger.Ledger
open Frontier_base
module Ledger_transfer_any =
  Mina_ledger.Ledger_transfer.Make (Ledger.Any_ledger.M) (Ledger.Any_ledger.M)

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

(* TODO: create a reusable singleton factory abstraction *)
module rec Instance_type : sig
  type t =
    { snarked_ledger : Ledger.Root.t
    ; potential_snarked_ledgers : Ledger.Root.Config.t Queue.t
    ; factory : Factory_type.t
    }
end =
  Instance_type

and Factory_type : sig
  type t =
    { directory : string
    ; logger : Logger.t
    ; mutable instance : Instance_type.t option
    ; ledger_depth : int
    ; backing_type : Ledger.Root.Config.backing_type
    }
end =
  Factory_type

open Instance_type
open Factory_type

module Instance = struct
  type t = Instance_type.t

  module Config = struct
    (** Helper to create a filesystem location (for a file or directory) inside
        the [Factory_type.t] directory. *)
    let make_instance_location filename t = Filename.concat t.directory filename

    (** Helper to create a [Root.Config.t] for a snarked ledger based on a
        subdirectory of the [Factory_type.t] directory *)
    let make_instance_config subdirectory t =
      Ledger.Root.Config.with_directory ~backing_type:t.backing_type
        ~directory_name:(make_instance_location subdirectory t)

    (** The config for the actual snarked ledger that is initialized and used by
        the daemon *)
    let snarked_ledger = make_instance_config "snarked_ledger"

    (** The config for the temporary snarked ledger, used while recovering a
        vaild potential snarked ledger during startup *)
    let tmp_snarked_ledger = make_instance_config "tmp_snarked_ledger"

    (** The name of a json file that lists the directory names of the potential
        snarked ledgers in the [potential_snarked_ledgers] queue *)
    let potential_snarked_ledgers =
      make_instance_location "potential_snarked_ledgers.json"

    (** A method that generates fresh potential snarked ledger configs, each
        using a distinct root subdirectory *)
    let make_potential_snarked_ledger t =
      let uuid = Uuid_unix.create () in
      make_instance_config ("snarked_ledger" ^ Uuid.to_string_hum uuid) t

    (** The name of the file recording the [Root_identifier.t] of the snarked
        root *)
    let root_identifier = make_instance_location "root"
  end

  let potential_snarked_ledgers_to_yojson queue =
    `List (List.map (Queue.to_list queue) ~f:Ledger.Root.Config.to_yojson)

  let potential_snarked_ledgers_of_yojson json =
    Yojson.Safe.Util.to_list json
    |> List.map ~f:(fun json ->
           Ledger.Root.Config.of_yojson json |> Result.ok_or_failwith )

  let load_potential_snarked_ledgers_from_disk factory =
    let location = Config.potential_snarked_ledgers factory in
    if phys_equal (Sys.file_exists location) `Yes then
      Yojson.Safe.from_file location |> potential_snarked_ledgers_of_yojson
    else []

  let write_potential_snarked_ledgers_to_disk t =
    Yojson.Safe.to_file
      (Config.potential_snarked_ledgers t.factory)
      (potential_snarked_ledgers_to_yojson t.potential_snarked_ledgers)

  let enqueue_snarked_ledger ~config t =
    Queue.enqueue t.potential_snarked_ledgers config ;
    write_potential_snarked_ledgers_to_disk t

  let dequeue_snarked_ledger t =
    let config = Queue.dequeue_exn t.potential_snarked_ledgers in
    Ledger.Root.Config.delete_any_backing config ;
    write_potential_snarked_ledgers_to_disk t

  let destroy t =
    List.iter
      (Queue.to_list t.potential_snarked_ledgers)
      ~f:Ledger.Root.Config.delete_any_backing ;
    Mina_stdlib_unix.File_system.rmrf
      (Config.potential_snarked_ledgers t.factory) ;
    Ledger.Root.close t.snarked_ledger ;
    t.factory.instance <- None

  let close t =
    Ledger.Root.close t.snarked_ledger ;
    t.factory.instance <- None

  let create ~logger factory =
    let snarked_ledger =
      Ledger.Root.create ~logger ~depth:factory.ledger_depth
        ~config:(Config.snarked_ledger factory)
        ()
    in
    { snarked_ledger; potential_snarked_ledgers = Queue.create (); factory }

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
        ~f:(fun _ config ->
          let potential_snarked_ledger =
            Ledger.Root.create ~logger ~depth:factory.ledger_depth ~config ()
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
              Ledger.Root.create ~logger ~depth:factory.ledger_depth
                ~config:(Config.tmp_snarked_ledger factory)
                ()
            in
            match
              Ledger_transfer_any.transfer_accounts
                ~src:(Ledger.Root.as_unmasked potential_snarked_ledger)
                ~dest:(Ledger.Root.as_unmasked snarked_ledger)
            with
            | Ok _ ->
                Ledger.Root.close potential_snarked_ledger ;
                Ledger.Root.Config.delete_any_backing
                @@ Config.snarked_ledger factory ;
                Ledger.Root.Config.move_backing_exn
                  ~src:(Config.tmp_snarked_ledger factory)
                  ~dst:(Config.snarked_ledger factory) ;
                List.iter potential_snarked_ledgers
                  ~f:Ledger.Root.Config.delete_any_backing ;
                Mina_stdlib_unix.File_system.rmrf
                  (Config.potential_snarked_ledgers factory) ;
                Stop (Some snarked_ledger)
            | Error e ->
                Ledger.Root.close potential_snarked_ledger ;
                List.iter potential_snarked_ledgers
                  ~f:Ledger.Root.Config.delete_any_backing ;
                Mina_stdlib_unix.File_system.rmrf
                  (Config.potential_snarked_ledgers factory) ;
                [%log' error factory.logger]
                  ~metadata:[ ("error", `String (Error.to_string_hum e)) ]
                  "Ledger_transfer failed" ;
                Stop None )
          else (
            Ledger.Root.close potential_snarked_ledger ;
            Continue None ) )
        ~finish:(fun _ ->
          List.iter potential_snarked_ledgers
            ~f:Ledger.Root.Config.delete_any_backing ;
          Mina_stdlib_unix.File_system.rmrf
            (Config.potential_snarked_ledgers factory) ;
          None )
    in
    match snarked_ledger with
    | None ->
        let snarked_ledger =
          Ledger.Root.create ~logger ~depth:factory.ledger_depth
            ~config:(Config.snarked_ledger factory)
            ()
        in
        let potential_snarked_ledger_hash =
          Frozen_ledger_hash.of_ledger_hash
          @@ Ledger.Root.merkle_root snarked_ledger
        in
        if
          Frozen_ledger_hash.equal potential_snarked_ledger_hash
            snarked_ledger_hash
        then
          Ok
            { snarked_ledger
            ; potential_snarked_ledgers = Queue.create ()
            ; factory
            }
        else (
          Ledger.Root.close snarked_ledger ;
          Error `Snarked_ledger_mismatch )
    | Some snarked_ledger ->
        Ok
          { snarked_ledger
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
    with_file (Config.root_identifier t.factory) `Write ~size ~f:(fun buf ->
        ignore
          ( Root_identifier.Stable.Latest.bin_write_t buf ~pos:0
              new_root_identifier
            : int ) )

  (* defaults to genesis *)
  let load_root_identifier t =
    let file = Config.root_identifier t.factory in
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

let create ~logger ~directory ~backing_type ~ledger_depth =
  { directory; logger; instance = None; ledger_depth; backing_type }

let create_instance_exn t =
  assert (Option.is_none t.instance) ;
  let instance = Instance.create ~logger:t.logger t in
  t.instance <- Some instance ;
  instance

let load_from_disk_exn t ~snarked_ledger_hash ~logger =
  let open Result.Let_syntax in
  assert (Option.is_none t.instance) ;
  let%map instance = Instance.load_from_disk t ~snarked_ledger_hash ~logger in
  t.instance <- Some instance ;
  instance

let with_instance_exn t ~f =
  let instance = create_instance_exn t in
  let x = f instance in
  Instance.close instance ; x

(** Clear the factory directory and recreate the snarked ledger instance for
    this factory with [create_root] and [setup] *)
let reset_factory_root_exn t ~create_root ~setup =
  let open Async.Deferred.Let_syntax in
  assert (Option.is_none t.instance) ;
  (* Certain database initialization methods, e.g. creation from a checkpoint,
     depend on the parent directory existing and the target directory _not_
     existing. *)
  let%bind () = Mina_stdlib_unix.File_system.remove_dir t.directory in
  let%map () = Mina_stdlib_unix.File_system.create_dir t.directory in
  let root =
    create_root
      ~config:(Instance.Config.snarked_ledger t)
      ~depth:t.ledger_depth ()
    |> Or_error.ok_exn
  in
  Ledger.Root.close root ;
  with_instance_exn t ~f:setup

let reset_to_genesis_exn t ~precomputed_values =
  reset_factory_root_exn t
    ~create_root:(Precomputed_values.create_root precomputed_values)
    ~setup:(fun instance ->
      Instance.set_root_identifier instance
        (genesis_root_identifier
           ~genesis_state_hash:
             (Precomputed_values.genesis_state_hashes precomputed_values)
               .state_hash ) )
