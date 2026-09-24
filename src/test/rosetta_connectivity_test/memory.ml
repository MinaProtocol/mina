(* Resident memory of the services under test, sampled during the load run.
   Reported to the bench database only: the old bash limits (postgres 3000 MiB,
   rosetta 300 MiB) were never calibrated, so they do not fail the run. *)

open Core
open Async

type t =
  { groups : (string * (unit -> float Deferred.t)) list
  ; samples : (string, float list) Hashtbl.t
  }

(* [groups] maps a report name ("rosetta") to the services whose RSS is
   summed under it. Postgres is not our child in CI (pg_ctlcluster starts it),
   so it is summed over every process named postgres. *)
let create ~local_postgres ~(services : (string * Proc.service list) list) =
  let sum_services services () =
    List.sum
      (module Float)
      services
      ~f:(fun s -> Option.value (Proc.rss_mib s) ~default:0.)
    |> return
  in
  let postgres =
    ( "postgres"
    , fun () ->
        Mina_automation.Utils.get_memory_usage_mib_of_user_process "postgres" )
  in
  let groups =
    (if local_postgres then [ postgres ] else [])
    @ List.map services ~f:(fun (name, services) ->
          (name, sum_services services) )
  in
  { groups; samples = Hashtbl.create (module String) }

let sample t =
  Deferred.List.iter t.groups ~f:(fun (name, measure) ->
      let%map mib = measure () in
      if Float.( > ) mib 0. then Hashtbl.add_multi t.samples ~key:name ~data:mib )

type stats = { max : float; p95 : float; p99 : float; median : float }

let stats t =
  List.map t.groups ~f:(fun (name, _) ->
      let sorted = Hashtbl.find_multi t.samples name |> Array.of_list in
      Array.sort sorted ~compare:Float.compare ;
      let at p =
        if Array.is_empty sorted then 0.
        else
          sorted.(Int.min
                    (Array.length sorted - 1)
                    (Float.iround_down_exn
                       (p *. Float.of_int (Array.length sorted)) ))
      in
      ( name
      , { max = (if Array.is_empty sorted then 0. else Array.last sorted)
        ; p95 = at 0.95
        ; p99 = at 0.99
        ; median = at 0.5
        } ) )
