(* Resident memory of the services under load, sampled during the run and
   reported, never checked: the old bash limits (postgres 3000 MiB, rosetta
   300 MiB) were never calibrated. *)

open Core
open Async

type t =
  { groups : (string * (unit -> float option Deferred.t)) list
  ; samples : (string, float list) Hashtbl.t
  }

(* [groups] maps a report name ("rosetta") to how to measure it in MiB; [None]
   is a sample that could not be taken. *)
let create groups = { groups; samples = Hashtbl.create (module String) }

let none = create []

let sample t =
  Deferred.List.iter t.groups ~f:(fun (name, measure) ->
      match%map measure () with
      | Some mib when Float.( > ) mib 0. ->
          Hashtbl.add_multi t.samples ~key:name ~data:mib
      | _ ->
          () )

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
