(** Does this binary match the schema it is reading?

    Every process that opens the archive database links [archive_lib] and is
    therefore compiled against era-specific types -- [Max_state_size] is
    [Nat.N32] in mesa where it was [N8] in berkeley, so an account decoded by
    the wrong binary is not a version inconvenience but a misread.

    Nothing checks this today. A stale reader against a migrated schema either
    fails with confusing SQL errors or, worse, succeeds and returns wrong data.
    That is a live hazard independent of any automation: it applies to every
    operator who upgrades their archive and their Rosetta at different times.

    [migration_history] already records which era the schema is in, and the
    upgrade script writes it, so this reads it directly rather than inferring
    anything. A reader that finds itself on the wrong side stands down with a
    clean exit, and whatever supervises it starts the right binary -- the
    dispatcher decides that from the same record. *)

open Core
open Async

type verdict =
  | Matches  (** The schema is the era this binary was built for. Carry on. *)
  | Differs of { schema : string; mine : string }
      (** The schema belongs to another era. Nothing this binary reads can be
          trusted, so it should stand down rather than answer. *)
  | Migration_in_progress of string
      (** The schema is mid-change. No binary matches it while that is true. *)
  | No_record
      (** No migration has ever been recorded, which is the ordinary state of a
          database that has not been through a fork. Nothing to object to. *)

let describe = function
  | Matches ->
      "the schema matches this binary"
  | Differs { schema; mine } ->
      sprintf
        "the schema is at protocol version %s but this binary was built for %s"
        schema mine
  | Migration_in_progress status ->
      sprintf "a schema migration is in state '%s'" status
  | No_record ->
      "no schema migration has been recorded"

let my_protocol_version = Protocol_version.(to_string current)

(** The decision itself, separated from reading the row so that it can be
    exercised without a database. *)
let verdict_of_row ~mine row =
  match row with
  | None ->
      No_record
  | Some (status, protocol_version, _migration_version) ->
      if not (String.equal status "applied") then Migration_in_progress status
      else if String.equal protocol_version mine then Matches
      else Differs { schema = protocol_version; mine }

let check (module Conn : Mina_caqti.CONNECTION) =
  let open Deferred.Let_syntax in
  match%map Hardfork_sql.fetch_latest_migration_history (module Conn) with
  | Ok row ->
      Ok (verdict_of_row ~mine:my_protocol_version row)
  | Error e ->
      (* No such table is not a failure to ask, it is an answer: this database
         has never been migrated, which is the ordinary state of one that has
         never been through a fork. create_schema.sql does not create
         migration_history -- only the upgrade does -- so treating its absence
         as an error would warn every interval, for ever, on every archive that
         has never forked. The dispatcher reads the same absence the same way,
         and the two must not disagree. *)
      let msg = Caqti_error.show e in
      if String.is_substring msg ~substring:"migration_history" then
        Ok No_record
      else Error e

let%test_module "schema era verdicts" =
  ( module struct
    let mine = "4.0.0"

    let%test_unit "a database that has never migrated raises no objection" =
      match verdict_of_row ~mine None with
      | No_record ->
          ()
      | v ->
          failwithf "expected No_record, got: %s" (describe v) ()

    let%test_unit "the schema this binary was built for matches" =
      match verdict_of_row ~mine (Some ("applied", "4.0.0", "0.0.6")) with
      | Matches ->
          ()
      | v ->
          failwithf "expected Matches, got: %s" (describe v) ()

    let%test_unit "an older schema is a mismatch, not a match" =
      match verdict_of_row ~mine (Some ("applied", "3.0.0", "0.0.1")) with
      | Differs { schema; mine = m } ->
          [%test_eq: string] schema "3.0.0" ;
          [%test_eq: string] m mine
      | v ->
          failwithf "expected Differs, got: %s" (describe v) ()

    let%test_unit "a migration in progress matches nothing, even at our version"
        =
      (* The version is ours, but the schema is mid-change: answering from it
         would be answering from a shape that is still moving. *)
      match verdict_of_row ~mine (Some ("starting", "4.0.0", "0.0.6")) with
      | Migration_in_progress status ->
          [%test_eq: string] status "starting"
      | v ->
          failwithf "expected Migration_in_progress, got: %s" (describe v) ()

    let%test_unit "a failed migration matches nothing either" =
      match verdict_of_row ~mine (Some ("failed", "4.0.0", "0.0.6")) with
      | Migration_in_progress status ->
          [%test_eq: string] status "failed"
      | v ->
          failwithf "expected Migration_in_progress, got: %s" (describe v) ()
  end )

(** Watch for the schema moving out from under this process.

    Polling rather than reacting, because there is nothing to react to: the
    migration is applied by a separate process against the database. The
    interval bounds how long this binary can keep answering from a schema that
    has changed, so it is short -- the queries are trivial.

    On a mismatch the process exits with status 0. Not a crash: a supervisor
    should read this as a clean hand-off and start the replacement in the
    ordinary way, rather than backing off as it would after a failure. *)
let watch ~logger ~pool ?(interval = Time.Span.of_sec 10.) () =
  Deferred.repeat_until_finished () (fun () ->
      let%bind () =
        match%map Mina_caqti.Pool.use (fun conn -> check conn) pool with
        | Error e ->
            (* Being unable to ask is not the same as being on the wrong side of
               a fork, and this process may be serving perfectly well from a
               connection that happens to be busy. Say so and try again. *)
            [%log warn]
              "Could not check whether this binary matches the schema: $error"
              ~metadata:[ ("error", `String (Caqti_error.show e)) ]
        | Ok (Matches | No_record) ->
            ()
        | Ok ((Differs _ | Migration_in_progress _) as verdict) ->
            [%log info]
              "Standing down: $reason. Exiting cleanly so the runtime matching \
               this schema can take over."
              ~metadata:[ ("reason", `String (describe verdict)) ] ;
            (* Give the log a chance to flush before the process goes. *)
            don't_wait_for
              (let%bind () = after (Time.Span.of_sec 1.) in
               exit 0 )
      in
      let%map () = after interval in
      `Repeat () )
