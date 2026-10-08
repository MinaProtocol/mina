(** When a binary that reads the archive database stands down after a hard
    fork.

    Every process that opens the archive database links [archive_lib] and is
    compiled against era-specific types, so a binary reading a schema of
    another era does not fail cleanly: it misreads.

    The decision uses two records:

    - [hardfork_state] says a fork has been announced. Until it has, there is
      no successor to hand over to, so a reader keeps serving whatever the
      schema says. An operator can therefore upgrade the schema before the
      fork, and the readers of the current era keep running on it.
    - [migration_history] says which era the schema is in. Once a fork is
      recorded and the schema belongs to another era, this binary stands down
      and the runtime matching the schema takes over. *)

open Core
open Async

module Verdict = struct
  type t =
    | Serve  (** Nothing to hand over to. Carry on. *)
    | Differs of { schema : string; mine : string }
        (** A fork is recorded and the schema belongs to another era. Nothing
            this binary reads can be trusted, so it stands down. *)
    | Migration_in_progress of Processor.Migration_history.Status.t
        (** A fork is recorded and the schema is mid-change. No binary matches
            it while that is true. *)
  [@@deriving sexp, compare, equal]

  let describe = function
    | Serve ->
        "no hard fork hand-over is due"
    | Differs { schema; mine } ->
        sprintf
          "a hard fork is recorded and the schema is at protocol version %s, \
           but this binary was built for %s"
          schema mine
    | Migration_in_progress status ->
        sprintf
          "a hard fork is recorded and a schema migration is in state '%s'"
          (Processor.Migration_history.Status.to_string status)

  (** The decision itself, separated from reading the rows so that it can be
      exercised without a database. *)
  let decide ~mine ~fork_recorded
      (migration : Processor.Migration_history.t option) =
    match (fork_recorded, migration) with
    | false, _ | true, None ->
        (* No fork, or a schema that never migrated: the schema is still of
           this binary's era. *)
        Serve
    | true, Some { status = (Starting | Failed) as status; _ } ->
        Migration_in_progress status
    | true, Some { status = Applied; protocol_version } ->
        if String.equal protocol_version mine then Serve
        else Differs { schema = protocol_version; mine }
end

let my_protocol_version = Protocol_version.(to_string current)

(* Older schemas lack one table or both, so a missing table is an answer:
   nothing migrated, nothing recorded. *)
let absent_table ~table e =
  String.is_substring (Caqti_error.show e) ~substring:table

let check (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Result.Let_syntax in
  let%bind fork_recorded =
    match%map.Deferred Processor.Hardfork_state.load_opt (module Conn) with
    | Ok recorded ->
        Ok (Option.is_some recorded)
    | Error e when absent_table ~table:"hardfork_state" e ->
        Ok false
    | Error e ->
        Error e
  in
  let%map migration =
    match%map.Deferred Processor.Migration_history.latest_opt (module Conn) with
    | Ok migration ->
        Ok migration
    | Error e when absent_table ~table:"migration_history" e ->
        Ok None
    | Error e ->
        Error e
  in
  Verdict.decide ~mine:my_protocol_version ~fork_recorded migration

let%test_module "schema era verdicts" =
  ( module struct
    open Verdict
    open Processor.Migration_history

    let mine = "1.0.0"

    let next = "2.0.0"

    let migration status protocol_version = Some { status; protocol_version }

    let expect ~fork_recorded migration expected =
      [%test_eq: Verdict.t] (decide ~mine ~fork_recorded migration) expected

    let%test_unit "no fork recorded: serve, even on an upgraded schema" =
      (* The schema is upgraded before the fork, and the readers of the
         current era keep running on it until the fork is recorded. *)
      expect ~fork_recorded:false (migration Applied next) Serve

    let%test_unit "no fork recorded: serve while a migration runs" =
      expect ~fork_recorded:false (migration Starting next) Serve

    let%test_unit "fork recorded, schema never migrated: serve" =
      expect ~fork_recorded:true None Serve

    let%test_unit "fork recorded, schema of this era: serve" =
      expect ~fork_recorded:true (migration Applied mine) Serve

    let%test_unit "fork recorded, schema of another era: stand down" =
      expect ~fork_recorded:true (migration Applied next)
        (Differs { schema = next; mine })

    let%test_unit "fork recorded, migration not applied: stand down" =
      List.iter [ Status.Starting; Failed ] ~f:(fun status ->
          expect ~fork_recorded:true (migration status next)
            (Migration_in_progress status) )
  end )

(** Watch for the hand-over becoming due.

    Polling, because the fork is recorded and the schema migrated by other
    processes. The interval bounds how long this binary can keep answering
    after it should have stopped.

    On a hand-over the process exits with status 0: a supervisor should read
    it as a clean hand-off, not a crash. *)
let watch ~logger ~pool ?(interval = Time.Span.of_sec 10.) () =
  Deferred.repeat_until_finished () (fun () ->
      let%bind () =
        match%map Mina_caqti.Pool.use (fun conn -> check conn) pool with
        | Error e ->
            (* Being unable to ask is not a reason to stop serving. *)
            [%log warn]
              "Could not check whether a hard fork hand-over is due: $error"
              ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        | Ok Verdict.Serve ->
            ()
        | Ok ((Differs _ | Migration_in_progress _) as verdict) ->
            (* Formatted in, not interpolated: plain-text logs drop
               interpolated values over fifty characters. *)
            [%log info]
              "Standing down: %s. Exiting cleanly so the runtime matching this \
               schema can take over."
              (Verdict.describe verdict) ;
            don't_wait_for
              (let%bind () = after (Time.Span.of_sec 1.) in
               exit 0 )
      in
      let%map () = after interval in
      `Repeat () )
