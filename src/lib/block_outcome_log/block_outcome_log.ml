open Core_kernel

type cache_outcome = [ `Consumed | `Failure | `Unconsumed ]
[@@deriving sexp, equal, compare]

type callback_outcome = [ `Accept | `Reject | `Ignore | `Expired ]
[@@deriving sexp, equal, compare]

type source = [ `Gossip | `Catchup | `Internal ]
[@@deriving sexp, equal, compare]

type event =
  | Cache_removed of { state_hash : string; outcome : cache_outcome }
  | Callback_resolved of { state_hash : string; outcome : callback_outcome }
  | Frontier_add of { state_hash : string; source : source; added : bool }
[@@deriving sexp, equal, compare]

(* The events recorded so far, newest first, while a test is recording. *)
let recorded : event list ref option ref = ref None

let record event =
  match !recorded with
  | None ->
      ()
  | Some events ->
      events := event () :: !events

let is_recording () = Option.is_some !recorded

module For_tests = struct
  let start () =
    if Option.is_some !recorded then failwith "Already recording block outcomes" ;
    let events = ref [] in
    recorded := Some events ;
    events

  let stop events =
    recorded := None ;
    List.rev !events

  let recording f =
    let events = start () in
    let result = Exn.protect ~f ~finally:(fun () -> recorded := None) in
    (result, stop events)

  let recording_deferred f =
    let open Async_kernel in
    let events = start () in
    let%map result =
      Monitor.protect ~here:[%here] f ~finally:(fun () ->
          recorded := None ;
          Deferred.unit )
    in
    (result, stop events)
end

let%test_module "Block_outcome_log" =
  ( module struct
    let cache_removed state_hash =
      Cache_removed { state_hash; outcome = `Consumed }

    let%test_unit "Only events recorded while recording are returned" =
      record (fun () -> cache_removed "before") ;
      let (), events =
        For_tests.recording (fun () ->
            record (fun () -> cache_removed "a") ;
            record (fun () -> cache_removed "b") )
      in
      record (fun () -> cache_removed "after") ;
      [%test_eq: event list] events [ cache_removed "a"; cache_removed "b" ]

    let%test_unit "Events aren't built unless recording" =
      record (fun () -> failwith "built an event while not recording")
  end )
