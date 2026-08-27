(** What the archive does once a daemon has told it about a hard fork.

    The daemon has the same choice, under the same flag name and with two of the
    same words: it either keeps running or migrates and exits. The archive's
    hand-over mirrors that, because it is the same event seen from the other
    side -- the pre-fork daemon stops, the pre-fork archive stops, and a
    dispatcher starts each of their successors.

    Why the archive has to stop at all: the work waiting on the other side of a
    fork is post-fork work. The genesis block belongs to the new era, and a
    pre-fork binary cannot build it -- its constants and its types are the old
    era's. So the process that records the fork is not the process that can act
    on it, and the only way to reach the right binary is to exit and let the
    dispatcher choose again. *)

open Core

type t =
  | Keep_running
      (** Record the fork and carry on. For an archive nobody restarts, and the
          default, so that upgrading the binary does not by itself change when
          an archive stops. *)
  | Exit
      (** Record the fork, then exit. The schema is somebody else's to upgrade
          -- an operator, or a step in the deployment. *)
  | Migrate_exit
      (** Record the fork, upgrade the schema, then exit. What the automode
          packaging sets: the restarted process finds a database whose schema
          matches the era it is about to serve. *)

let to_string = function
  | Keep_running ->
      "keep-running"
  | Exit ->
      "exit"
  | Migrate_exit ->
      "migrate-exit"

let all = [ Keep_running; Exit; Migrate_exit ]

let of_string s =
  match List.find all ~f:(fun t -> String.equal (to_string t) s) with
  | Some t ->
      Ok t
  | None ->
      Error
        (sprintf "unknown hard fork handling %S, expected one of %s" s
           (String.concat ~sep:", " (List.map all ~f:to_string)) )

let of_string_exn s =
  match of_string s with Ok t -> t | Error msg -> failwith msg

(** Whether this strategy ends the process. *)
let exits = function Keep_running -> false | Exit | Migrate_exit -> true

(** Whether this strategy upgrades the schema before it goes. *)
let upgrades_schema = function
  | Keep_running | Exit ->
      false
  | Migrate_exit ->
      true

let%test_unit "every strategy survives a round trip through its name" =
  List.iter all ~f:(fun t ->
      [%test_eq: string] (to_string t)
        (to_string (of_string_exn (to_string t))) )

let%test_unit "an unknown name is rejected, and says what it expected" =
  match of_string "migrate" with
  | Ok _ ->
      failwith "expected \"migrate\" to be rejected"
  | Error msg ->
      assert (String.is_substring msg ~substring:"migrate-exit")

let%test_unit "only migrate-exit upgrades, and keep-running alone stays" =
  [%test_eq: bool list]
    (List.map all ~f:exits)
    [ false; true; true ] ;
  [%test_eq: bool list]
    (List.map all ~f:upgrades_schema)
    [ false; false; true ]
