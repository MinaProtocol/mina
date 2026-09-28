(** Should this binary stop reading the archive database?

    Every process that opens the archive database links [archive_lib] and is
    compiled against era-specific types, so a binary reading a schema of
    another era does not fail cleanly: it misreads.

    Two records answer the question, and a reader needs both:

    - [hardfork_state] says a fork has been announced. Until it has, there is
      no successor to hand over to, so a reader keeps serving whatever the
      schema says. This is what lets an operator run upgrade.sql before the
      fork: the pre-fork archive and Rosetta keep running on the upgraded
      schema.
    - [migration_history] says which era the schema is in. Once a fork is
      recorded and the schema belongs to another era, this binary stands down
      and the runtime matching the schema takes over.

    The archive dispatcher routes on the same two records, so a reader never
    stands down only to be started again. *)

open Core
open Async
open Caqti_request.Infix

type migration = { status : string; protocol_version : string }

type verdict =
  | Serve  (** Nothing to hand over to. Carry on. *)
  | Differs of { schema : string; mine : string }
      (** A fork is recorded and the schema belongs to another era. Nothing
          this binary reads can be trusted, so it stands down. *)
  | Migration_in_progress of string
      (** A fork is recorded and the schema is mid-change. No binary matches
          it while that is true. *)

let describe = function
  | Serve ->
      "no hard fork hand-over is due"
  | Differs { schema; mine } ->
      sprintf
        "a hard fork is recorded and the schema is at protocol version %s, \
         but this binary was built for %s"
        schema mine
  | Migration_in_progress status ->
      sprintf "a hard fork is recorded and a schema migration is in state '%s'"
        status

let my_protocol_version = Protocol_version.(to_string current)

(** The decision itself, separated from reading the rows so that it can be
    exercised without a database. *)
let verdict ~mine ~fork_recorded (migration : migration option) =
  match (fork_recorded, migration) with
  | false, _ | true, None ->
      (* No fork, or a schema that never migrated: this binary is the one the
         dispatcher would start. *)
      Serve
  | true, Some { status; protocol_version } ->
      if not (String.equal status "applied") then Migration_in_progress status
      else if String.equal protocol_version mine then Serve
      else Differs { schema = protocol_version; mine }

let latest_migration_query =
  Caqti_type.(unit ->? t2 string string)
    {sql| SELECT status::text, protocol_version
          FROM migration_history
          ORDER BY commit_start_at DESC
          LIMIT 1
    |sql}

let fork_recorded_query =
  Caqti_type.(unit ->! bool)
    {sql| SELECT EXISTS (SELECT 1 FROM hardfork_state) |sql}

(* Both tables are created by upgrade.sql, not by the schema a 4.0.0 database
   was built with, so a missing table is an answer: nothing migrated, nothing
   recorded. *)
let absent_table ~table e =
  String.is_substring (Caqti_error.show e) ~substring:table

let check (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Result.Let_syntax in
  let%bind fork_recorded =
    match%map.Deferred Conn.find fork_recorded_query () with
    | Ok recorded ->
        Ok recorded
    | Error e when absent_table ~table:"hardfork_state" e ->
        Ok false
    | Error e ->
        Error e
  in
  let%map migration =
    match%map.Deferred Conn.find_opt latest_migration_query () with
    | Ok row ->
        Ok
          (Option.map row ~f:(fun (status, protocol_version) ->
               { status; protocol_version } ) )
    | Error e when absent_table ~table:"migration_history" e ->
        Ok None
    | Error e ->
        Error e
  in
  verdict ~mine:my_protocol_version ~fork_recorded migration

let%test_module "schema era verdicts" =
  ( module struct
    let mine = "4.0.0"

    let applied v = Some { status = "applied"; protocol_version = v }

    let expect_serve v =
      match v with
      | Serve ->
          ()
      | v ->
          failwithf "expected Serve, got: %s" (describe v) ()

    let%test_unit "no fork recorded: serve, even on an upgraded schema" =
      (* upgrade.sql runs before the fork. Standing down here would leave no
         runtime to start: the dispatcher still chooses this one. *)
      expect_serve (verdict ~mine ~fork_recorded:false (applied "5.0.0"))

    let%test_unit "no fork recorded: serve while a migration runs" =
      expect_serve
        (verdict ~mine ~fork_recorded:false
           (Some { status = "starting"; protocol_version = "5.0.0" }) )

    let%test_unit "fork recorded, schema never migrated: serve" =
      expect_serve (verdict ~mine ~fork_recorded:true None)

    let%test_unit "fork recorded, schema of this era: serve" =
      expect_serve (verdict ~mine ~fork_recorded:true (applied mine))

    let%test_unit "fork recorded, schema of another era: stand down" =
      match verdict ~mine ~fork_recorded:true (applied "5.0.0") with
      | Differs { schema; mine = m } ->
          [%test_eq: string] schema "5.0.0" ;
          [%test_eq: string] m mine
      | v ->
          failwithf "expected Differs, got: %s" (describe v) ()

    let%test_unit "fork recorded, migration not applied: stand down" =
      List.iter [ "starting"; "failed" ] ~f:(fun status ->
          match
            verdict ~mine ~fork_recorded:true
              (Some { status; protocol_version = "5.0.0" })
          with
          | Migration_in_progress s ->
              [%test_eq: string] s status
          | v ->
              failwithf "expected Migration_in_progress, got: %s" (describe v)
                () )
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
        | Ok Serve ->
            ()
        | Ok ((Differs _ | Migration_in_progress _) as verdict) ->
            (* Formatted in, not interpolated: plain-text logs drop
               interpolated values over fifty characters. *)
            [%log info]
              "Standing down: %s. Exiting cleanly so the runtime matching this \
               schema can take over."
              (describe verdict) ;
            don't_wait_for
              (let%bind () = after (Time.Span.of_sec 1.) in
               exit 0 )
      in
      let%map () = after interval in
      `Repeat () )
