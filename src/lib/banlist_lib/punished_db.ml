open Core_kernel
open Async_kernel

module type Time_intf = sig
  type t [@@deriving compare]

  val now : unit -> t
end

module type Punishment_record_intf = sig
  type t

  type time

  val eviction_time : t -> time
end

module Make
    (Peer : Hashable.S)
    (Time : Time_intf)
    (Punishment_record : Punishment_record_intf with type time := Time.t)
    (DB : Key_value_database.S
          with type key := Peer.t
           and type value := Punishment_record.t) :
  Key_value_database.S
  with type key := Peer.t
   and type value := Punishment_record.t = struct
  type t = {db: DB.t}

  let create ~directory =
    let db = DB.create ~directory in
    {db}

  let set {db} ~key ~data = DB.set db ~key ~data

  let get {db} ~key =
    DB.get db ~key
    |> Option.bind ~f:(fun record ->
           let current_time = Time.now () in
           if
             Time.compare (Punishment_record.eviction_time record) current_time
             < 0
           then ( DB.remove db ~key ; None )
           else Some record )

  let close {db} = DB.close db

  let remove {db} = DB.remove db
end

module Mock_time = struct
  type t = Time_simulator.t [@@deriving compare]

  let controller = ref (Time_simulator.Controller.create ())

  let diff = Time_simulator.diff

  let now () = Time_simulator.now !controller

  let tick () = Time_simulator.Controller.tick !controller

  let with_simulator ~f =
    let ctrl = Time_simulator.Controller.create () in
    controller := ctrl ;
    f ()

  let set_event ~f time =
    ignore
      ( Time_simulator.Timeout.create !controller time ~f
        : unit Time_simulator.Timeout.t )
end

let%test_module "banlist" =
  ( module struct
    let peer = 1

    module Mock_punishment = struct
      type t = Int64.t

      let eviction_time = Fn.id
    end

    module Storage = Key_value_database.Make_mock (Int) (Mock_punishment)
    module Mock_db = Make (Int) (Mock_time) (Mock_punishment) (Storage)

    let schedule_punishment_lookup db is_punished time =
      Mock_time.set_event time ~f:(fun _time ->
          is_punished := Mock_db.get db ~key:peer |> Option.is_some )

    let simulated_elapse_ms_to_change_state = 10240

    let%test_unit "time logic" =
      Mock_time.with_simulator ~f:(fun _ ->
          let _ = Mock_time.now () in
          let db = Mock_db.create ~directory:"" in
          let is_punished = ref true in
          let evict_time = Int64.of_int simulated_elapse_ms_to_change_state in
          Mock_db.set db ~key:peer ~data:evict_time ;
          schedule_punishment_lookup db is_punished (Int64.pred evict_time) ;
          schedule_punishment_lookup db is_punished (Int64.succ evict_time) ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind () = Mock_time.tick () in
              [%test_result: Bool.t] ~message:"peer should still be banned"
                ~expect:true !is_punished ;
              let%map () = Mock_time.tick () in
              [%test_result: Bool.t] ~message:"peer is not banned anymore"
                ~expect:false !is_punished ) )

    let%test_unit "updating a peer's ban record will override their time to \
                   evict (regardless)" =
      Mock_time.with_simulator ~f:(fun _ ->
          let _ = Mock_time.now () in
          let db = Mock_db.create ~directory:"" in
          let is_punished = ref true in
          let old_evict_time =
            Int64.of_int simulated_elapse_ms_to_change_state
          in
          let new_evict_time = old_evict_time |> Int64.succ |> Int64.succ in
          schedule_punishment_lookup db is_punished (Int64.succ old_evict_time) ;
          schedule_punishment_lookup db is_punished (Int64.succ new_evict_time) ;
          Mock_db.set db ~key:peer ~data:old_evict_time ;
          Mock_db.set db ~key:peer ~data:new_evict_time ;
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind () = Mock_time.tick () in
              [%test_result: Bool.t] ~message:"peer should still be banned"
                ~expect:true !is_punished ;
              let%map () = Mock_time.tick () in
              [%test_result: Bool.t] ~message:"peer is not banned anymore"
                ~expect:false !is_punished ) )
  end )
