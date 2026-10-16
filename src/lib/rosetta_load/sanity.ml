(* One call per endpoint, about an object taken from the archive behind the
   Rosetta: a random canonical block, MINA account and transaction. Those are
   in the archive by construction, so a wrong answer is Rosetta's. *)

open Core
open Async

let run ~client ~db =
  Deferred.Or_error.List.iter Endpoint.all ~f:(fun endpoint ->
      let open Deferred.Or_error.Let_syntax in
      let%bind args = Sql.sample db endpoint ~limit:1 in
      match args with
      | [] ->
          Deferred.Or_error.errorf "sanity %s: the archive has nothing to ask"
            (Endpoint.name endpoint)
      | arg :: _ -> (
          let%map.Deferred { result; _ } = Endpoint.call client endpoint ~arg in
          match result with
          | Ok () ->
              Progress.printf "sanity %s: ok %s" (Endpoint.name endpoint) arg ;
              Ok ()
          | Error msg ->
              (* [msg] already names [arg] *)
              Or_error.errorf "sanity %s: %s" (Endpoint.name endpoint) msg ) )
