(* Only show stdout for failed inline tests. *)
open Core_kernel

module type Db = sig
  module T : sig
    type ('k, 'v) t
  end

  include module type of Intf.Db (T)
end

type config =
  { initial_mmap_size : int
  ; mmap_growth_factor : float
  ; mmap_growth_max_step : int
  }

let default_config =
  { initial_mmap_size = 64 lsl 20 (* 64 MiB *)
  ; mmap_growth_factor = 1.5
  ; mmap_growth_max_step = 4 lsl 30 (* 4 GiB *)
  }

module type F = functor (Db : Db) -> sig
  type holder

  val mk_maps : Db.creator -> holder

  val config : config
end

module Base (F_func : F) = struct
  type ('k, 'v) db = ('k, 'v, [ `Uni ]) Lmdb.Map.t

  type ('k, 'v) initialize_f =
    { initialize :
        'a.
           ?txn:([< `Read | `Write > `Read ] as 'a) Lmdb.Txn.t
        -> Lmdb.Env.t
        -> ('k, 'v) db
    }

  type ('k, 'v) lazy_db =
    [ `Uninitialized of ('k, 'v) initialize_f | `Initialized of ('k, 'v) db ]
    ref

  module Db = struct
    module T = struct
      type ('k, 'v) t = ('k, 'v) lazy_db
    end

    include Intf.Db (T)
  end

  module F = F_func (Db)

  type holder = F.holder

  type t =
    { dir : string
    ; env : Lmdb.Env.t option ref
    ; max_maps : int
    ; pagesize : int
    }

  let env_flags = Lmdb.Mdb.EnvFlags.(no_read_ahead + write_map)

  let create dir =
    let pagesize =
      Option.(
        value ~default:4096 (Core.Unix.(sysconf PAGESIZE) >>= Int64.to_int))
    in
    let max_maps = ref 0 in
    let mk_map ?name key value =
      max_maps := !max_maps + 1 ;
      ref
        (`Uninitialized
          { initialize =
              (fun ?txn -> Lmdb.Map.open_existing ?txn ?name Nodup ~key ~value)
          } )
    in
    let h = F.mk_maps { create = mk_map } in
    ({ max_maps = !max_maps; env = ref None; dir; pagesize }, h)

  let open_env ~force ~perm ~max_maps dir =
    let create_do () =
      Lmdb.Env.create ~flags:env_flags ~max_maps
        ~map_size:F.config.initial_mmap_size perm dir
    in
    if Sys.file_exists dir then Some (create_do ())
    else if force then (
      Core.Unix.mkdir_p ~perm:0777 dir ;
      Some (create_do ()) )
    else None

  let roundup multiple value =
    multiple
    * ( Float.of_int value /. Float.of_int multiple
      |> Float.round_up |> Float.to_int )

  let next_size ~pagesize map_size =
    let default = map_size + F.config.mmap_growth_max_step in
    roundup pagesize @@ Option.value ~default
    @@ let%bind.Option next =
         Float.of_int map_size *. F.config.mmap_growth_factor |> Float.iround_up
       in
       let%map.Option () = Option.some_if (next < default) () in
       next

  let with_env ?(force = false) ~perm ~default ~f:unwrapped_f t =
    let rec f env =
      try unwrapped_f env with
      | Lmdb.Map_full ->
          (* MDB_MAP_FULL *)
          let map_size = (Lmdb.Env.info env).map_size in
          Lmdb.Env.set_map_size env (next_size ~pagesize:t.pagesize map_size) ;
          f env
      | Lmdb.Error -30785 ->
          (* MDB_MAP_RESIZED *)
          Lmdb.Env.set_map_size env 0 ;
          f env
    in
    match !(t.env) with
    | Some env ->
        f env
    | None ->
        let env_opt = open_env ~force ~perm ~max_maps:t.max_maps t.dir in
        t.env := env_opt ;
        Option.value_map ~f ~default env_opt

  let init_db ~env ?txn lazy_db =
    match !lazy_db with
    | `Initialized db ->
        db
    | `Uninitialized { initialize } ->
        let db = initialize ?txn env in
        lazy_db := `Initialized db ;
        db

  let get_impl ?txn ~env lazy_db key =
    try Lmdb.Map.get ?txn (init_db ?txn ~env lazy_db) key |> Some
    with Lmdb.Not_found -> None

  let set_impl ?txn ~env lazy_db key value =
    Lmdb.Map.set ?txn (init_db ?txn ~env lazy_db) key value

  let remove_impl ?txn ~env lazy_db key =
    Lmdb.Map.remove ?txn (init_db ?txn ~env lazy_db) key ?value:None

  let iter_impl ?txn ~env ~perm ~iter_f lazy_db =
    let run_cursor cursor =
      try iter_f cursor (Lmdb.Cursor.first cursor) with Lmdb.Not_found -> ()
    in
    let db = init_db ?txn ~env lazy_db in
    Lmdb.Cursor.go perm ?txn db run_cursor

  let iter_ro_impl ~perm ~f =
    let rec iter_f cursor (k, v) =
      match f k v with
      | `Continue ->
          iter_f cursor (Lmdb.Cursor.next cursor)
      | `Stop ->
          ()
    in
    iter_impl ~perm ~iter_f

  let iter_rw_impl ~f =
    let rec iter_f cursor (k, v) =
      match f k v with
      | `Continue ->
          iter_f cursor (Lmdb.Cursor.next cursor)
      | `Stop ->
          ()
      | `Remove_continue ->
          Lmdb.Cursor.remove cursor ;
          iter_f cursor (Lmdb.Cursor.next cursor)
      | `Remove_stop ->
          Lmdb.Cursor.remove cursor
      | `Update_continue v' ->
          Lmdb.Cursor.set cursor k v' ;
          iter_f cursor (Lmdb.Cursor.next cursor)
      | `Update_stop v' ->
          Lmdb.Cursor.set cursor k v'
    in
    iter_impl ~perm:Rw ~iter_f

  let getter ?txn ~perm ~env =
    { Db.get = (fun db key -> get_impl ?txn ~env db key)
    ; iter_ro = (fun ~f db -> iter_ro_impl ~perm ?txn ~env ~f db)
    }

  let setter ?(txn : [< `Read | `Write > `Read ] Lmdb.Txn.t option) ~env =
    { Db.set = (fun db key value -> set_impl ?txn ~env db key value)
    ; iter_rw = (fun ~f db -> iter_rw_impl ?txn ~env ~f db)
    }

  let close { env; _ } = Option.iter ~f:Lmdb.Env.close !env
end

module Read_only (F_func : F) = struct
  include Base (F_func)

  let get ~env:t db key =
    with_env t ~perm:Ro ~default:None ~f:(fun env -> get_impl ~env db key)

  let with_txn ~f t =
    with_env t ~perm:Ro ~default:None ~f:(fun env ->
        Lmdb.Txn.go Ro env (fun txn -> f @@ getter ~perm:Ro ~txn ~env) )

  let iter ~env:t db ~f =
    with_env t ~perm:Ro ~default:() ~f:(fun env ->
        iter_ro_impl ~perm:Ro ~env db ~f )
end

module Read_write (F_func : F) = struct
  include Base (F_func)

  let get ~env:t db key =
    with_env t ~perm:Rw ~default:None ~f:(fun env -> get_impl ~env db key)

  let set ~env:t db key value =
    with_env t ~force:true ~perm:Rw ~default:() ~f:(fun env ->
        set_impl ~env db key value )

  let with_txn ?(perm = Lmdb.Rw) ~f t =
    with_env t ~perm:Rw ~default:None ~f:(fun env ->
        Lmdb.Txn.go perm env (fun txn ->
            f (getter ~txn ~env ~perm) (setter ~txn ~env) ) )

  let iter_ro ~env:t db ~f =
    with_env t ~perm:Rw ~default:() ~f:(fun env ->
        iter_ro_impl ~perm:Ro ~env db ~f )

  let iter ~env:t db ~f =
    with_env t ~force:true ~perm:Rw ~default:() ~f:(fun env ->
        iter_rw_impl ~env db ~f )

  let remove ~env:t db key =
    with_env t ~perm:Rw ~default:() ~f:(fun env -> remove_impl ~env db key)
end
