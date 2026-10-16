(* Resident memory of the services under load, sampled during the run and
   reported, never checked: there is no calibrated limit to check against. *)

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

(* [nan] for a group with no sample. *)
type stats = { max : float; p95 : float; p99 : float; median : float }

let stats t =
  let module S = Bench_report.Stats in
  List.map t.groups ~f:(fun (name, _) ->
      let sorted = S.sorted (Hashtbl.find_multi t.samples name) in
      let or_nan = Option.value ~default:Float.nan in
      ( name
      , { max = or_nan (S.max sorted)
        ; p95 = or_nan (S.percentile sorted 0.95)
        ; p99 = or_nan (S.percentile sorted 0.99)
        ; median = or_nan (S.percentile sorted 0.5)
        } ) )
