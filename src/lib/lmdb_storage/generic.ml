(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs
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
end

let%test_module "Lmdb storage tests" =
  ( module struct
    open Async_kernel

    module F (Db : Db) = struct
      type holder = (int, Bigstring.t) Db.t

      let mk_maps { Db.create } = create Conv.uint32_be Lmdb.Conv.bigstring

      let config = { default_config with initial_mmap_size = 1 lsl 20 }
    end

    module Rw = Read_write (F)
    module Ro = Read_only (F)

    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let test_with_dir f =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind dir = Async.Unix.mkdtemp "lmdb_storage" in
          Monitor.protect
            (fun () -> f dir)
            ~finally:(fun () -> File_system.remove_dir dir) )

    let uint32 =
      Base_quickcheck.Generator.int_uniform_inclusive 0
        Int32.(to_int_exn max_value)

    let%test_unit "Put many keys to reach mmap resize" =
      let n = 300 in
      test_with_dir
      @@ fun dir ->
      let env, db = Rw.create dir in
      Quickcheck.test
        (Quickcheck.Generator.both uint32
           (String.gen_with_length 100000
              Base_quickcheck.quickcheck_generator_char ) )
        ~trials:n
        ~f:(fun (k, v) -> Rw.set ~env db k (Bigstring.of_string v)) ;
      Deferred.unit

    let%test_unit "Iterations with removal and re-opening of database" =
      let n = 300 in
      let hm = Hashtbl.create (module Int) in
      let odd_cnt = ref 0 in
      test_with_dir
      @@ fun dir ->
      let env, db = Rw.create dir in
      Quickcheck.test
        (Quickcheck.Generator.both uint32
           (String.gen_with_length 100 Base_quickcheck.quickcheck_generator_char) )
        ~trials:n
        ~f:(fun (k, v_str) ->
          let v = Bigstring.of_string v_str in
          Hashtbl.add ~key:k ~data:v hm
          |> function
          | `Duplicate ->
              ()
          | `Ok ->
              if k % 2 = 1 then odd_cnt := !odd_cnt + 1 ;
              Rw.set ~env db k v ) ;
      Hashtbl.iteri hm ~f:(fun ~key ~data ->
          [%test_eq: Bigstring.t option] (Some data) (Rw.get ~env db key) ) ;
      let cnt = ref 0 in
      Rw.iter ~env db ~f:(fun k data ->
          cnt := !cnt + 1 ;
          [%test_eq: Bigstring.t option] (Some data) (Hashtbl.find hm k) ;
          if k % 2 = 0 then `Remove_continue else `Continue ) ;
      assert (!cnt = Hashtbl.length hm) ;
      cnt := 0 ;
      Rw.iter_ro ~env db ~f:(fun k data ->
          [%test_eq: Bigstring.t option] (Some data) (Hashtbl.find hm k) ;
          cnt := !cnt + 1 ;
          `Continue ) ;
      assert (!cnt = !odd_cnt) ;
      Rw.close env ;
      let env, db = Ro.create dir in
      Hashtbl.iteri hm ~f:(fun ~key ~data ->
          [%test_eq: Bigstring.t option]
            (Option.some_if (key % 2 = 1) data)
            (Ro.get ~env db key) ) ;
      cnt := 0 ;
      Ro.iter ~env db ~f:(fun k data ->
          [%test_eq: Bigstring.t option] (Some data) (Hashtbl.find hm k) ;
          cnt := !cnt + 1 ;
          `Continue ) ;
      assert (!cnt = !odd_cnt) ;
      Deferred.unit

    (* TODO consider testing get, set and iter from within with_txn *)
    (* TODO consider testing all "outcomes" within iter's function *)
  end )
