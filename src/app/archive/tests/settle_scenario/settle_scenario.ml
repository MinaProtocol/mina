(** Settle test cases: a hand-built archive (the input blocks) and the chain
    statuses it ends with.

    {[
      { name = "fork on a pending block"
      ; blocks =
          [ block "A" ~height:1 Canonical
          ; block "B" ~parent:"A" ~height:2 Pending
          ; block "C" ~parent:"B" ~height:3 Pending
          ; block "D" ~parent:"B" ~height:3 Pending
          ; fork_genesis ~fork_block:"C" ~height:4 ()
          ]
      ; outcome =
          Settled [ ("B", Canonical); ("C", Canonical); ("D", Orphaned) ]
      }
    ]}

    An outcome lists only the blocks whose chain status changes; every other
    block keeps the status it was built with. What a test does with the
    archive (settle it, start the archive on it, mark a block) is the test's
    own; this module builds the archive and checks it. Shared by the archive's
    settle tests and the hardfork toolbox's convert-chain-to-canonical
    tests. *)

open Core
open Async
open Mina_base
module B = Synthetic_archive
module Settle = Archive_lib.Settle_pending_blocks

(** A block's chain status, as the archive's [chain_status] column holds
    it. *)
module Status = struct
  type t = B.chain_status = Canonical | Orphaned | Pending [@@deriving equal]

  let to_string = function
    | Canonical ->
        "canonical"
    | Orphaned ->
        "orphaned"
    | Pending ->
        "pending"

  let of_string s =
    match s with
    | "canonical" ->
        Canonical
    | "orphaned" ->
        Orphaned
    | "pending" ->
        Pending
    | _ ->
        failwithf "unknown chain status %s" s ()
end

type status = Status.t = Canonical | Orphaned | Pending

(** {1 Input blocks} *)

type block =
  { name : string
  ; height : int
  ; status : status
  ; parent : [ `Linked of string | `Unlinked of string | `Not_in_archive ]
  ; protocol_version : int * int * int
  ; global_slot_since_genesis : int option
  ; global_slot_since_hard_fork : int option
  }

let v4 = (4, 0, 0)

let v5 = (5, 0, 0)

(** A block of the old chain (protocol version 4). Its parent, when given, is
    an earlier block of the list; without one, the block's parent is not in
    the archive. *)
let block ?parent ?(protocol_version = v4) ?global_slot_since_genesis
    ?global_slot_since_hard_fork name ~height status =
  { name
  ; height
  ; status
  ; parent = (match parent with Some p -> `Linked p | None -> `Not_in_archive)
  ; protocol_version
  ; global_slot_since_genesis
  ; global_slot_since_hard_fork
  }

(** A block of the new chain (protocol version 5). *)
let postfork ?parent ?global_slot_since_genesis ?global_slot_since_hard_fork
    name ~height status =
  block ?parent ~protocol_version:v5 ?global_slot_since_genesis
    ?global_slot_since_hard_fork name ~height status

(** A fork genesis (global slot since hard fork 0, canonical unless [status]
    says otherwise), named "genesis" by default. Its parent is [fork_block];
    with [~unlinked:true] only the parent hash is set, as before the archive
    links it; without [fork_block] the fork block is not in the archive. *)
let fork_genesis ?(name = "genesis") ?fork_block ?(unlinked = false)
    ?(protocol_version = v5) ?(status = Canonical) ~height () =
  { name
  ; height
  ; status
  ; parent =
      ( match fork_block with
      | None ->
          `Not_in_archive
      | Some p ->
          if unlinked then `Unlinked p else `Linked p )
  ; protocol_version
  ; global_slot_since_genesis = None
  ; global_slot_since_hard_fork = Some 0
  }

(** {1 Settle test cases} *)

(** What settling the newest fork genesis's boundary does. *)
type outcome =
  | Settled of (string * status) list
      (** It settles, and these blocks change to these statuses. *)
  | Refused of Settle.boundary
      (** It cannot settle, for this reason, and changes nothing. *)
  | Nothing_to_settle  (** There is no fork genesis. *)

type case = { name : string; blocks : block list; outcome : outcome }

(** The blocks an outcome changes. *)
let changes = function Settled c -> c | Refused _ | Nothing_to_settle -> []

(** {1 The archive a test runs on} *)

type ctx =
  { db : B.Db.t
  ; test : string  (** The test case's name. *)
  ; blocks : block list
  ; id : string -> int  (** A block's database id. *)
  ; state_hash : string -> string
  ; public_key : string -> string
        (** The public key of the account of this name. *)
  }

let find_block ~test blocks name =
  match List.find blocks ~f:(fun (b : block) -> String.equal b.name name) with
  | Some b ->
      b
  | None ->
      failwithf "%s: no block %s in the test case" test name ()

let height ctx name = (find_block ~test:ctx.test ctx.blocks name).height

(* A real state hash, by seed: a config can name the block by it. Made from
   60 bits of the seed's digest, so different seeds give different hashes. *)
let real_state_hash seed =
  let digest = Md5.to_hex (Md5.digest_string seed) in
  State_hash.of_decimal_string
    (Int.to_string (Int.of_string ("0x" ^ String.prefix digest 15)))
  |> State_hash.to_base58_check

(** The state hash of a block that is not in the archive, e.g. a fork block
    a config names. *)
let state_hash_not_in_archive ~test name =
  real_state_hash (sprintf "%s: %s, not in the archive" test name)

let caqti_error e = Error.of_string (Caqti_error.show e)

let with_conn (db : B.Db.t) f =
  match%bind Mina_caqti.connect db.uri with
  | Error e ->
      return (Error (caqti_error e))
  | Ok (module Conn : Mina_caqti.CONNECTION) ->
      (* disconnect even when [f] raises, or the database cannot be dropped *)
      Monitor.protect ~finally:Conn.disconnect (fun () ->
          f (module Conn : Mina_caqti.CONNECTION)
          >>| Result.map_error ~f:caqti_error )

let exec ctx sql =
  with_conn ctx.db (fun (module Conn) ->
      Conn.exec (Mina_caqti.exec_req Caqti_type.unit sql) () )

(** [what] of a test, named in its error. *)
let step what result = Deferred.Or_error.tag result ~tag:what

(** {1 Running} *)

(** Settle_pending_blocks.run, as the archive and the toolbox run it. *)
let settle ?dry_run ctx = with_conn ctx.db (Settle.run ?dry_run)

(** The archive's canonical marking as the named block arrives
    (Processor.Block.update_chain_status), with k = 2. *)
let mark_chain_status ctx name =
  let precomputed = Lazy.force Precomputed_values.for_unit_tests in
  let genesis_constants =
    { precomputed.genesis_constants with
      protocol = { precomputed.genesis_constants.protocol with k = 2 }
    }
  in
  with_conn ctx.db (fun (module Conn) ->
      Archive_lib.Processor.Block.update_chain_status
        (module Conn)
        ~logger:(Logger.null ()) ~genesis_constants ~block_id:(ctx.id name) )

(** {1 Checks} *)

(* The fork genesis a settle picks: the newest, by height. *)
let newest_fork_genesis ctx =
  List.filter ctx.blocks ~f:(fun (b : block) ->
      [%equal: int option] b.global_slot_since_hard_fork (Some 0) )
  |> List.max_elt ~compare:(fun (a : block) b -> Int.compare a.height b.height)
  |> Option.map ~f:(fun (b : block) -> ctx.id b.name)

(** The result Settle_pending_blocks.run reports for [outcome]: the newest
    fork genesis, and as many blocks made canonical and orphaned as the
    outcome lists. *)
let expected_result ctx outcome =
  let count status =
    List.count (changes outcome) ~f:(fun (_, s) -> Status.equal s status)
  in
  match outcome with
  | Nothing_to_settle ->
      { Settle.genesis_id = None; boundary = None }
  | Refused reason ->
      { genesis_id = newest_fork_genesis ctx; boundary = Some reason }
  | Settled _ ->
      { genesis_id = newest_fork_genesis ctx
      ; boundary =
          Some
            (Settled
               { canonicalized = count Canonical; orphaned = count Orphaned } )
      }

let check_result ctx outcome (got : Settle.t) =
  let want = expected_result ctx outcome in
  if Settle.equal want got then Ok ()
  else
    Or_error.errorf "settle result:\n  expected: %s\n  got:      %s"
      (Sexp.to_string (Settle.sexp_of_t want))
      (Sexp.to_string (Settle.sexp_of_t got))

(** Every block has the status it was built with, or the one [changes] gives
    it. *)
let check_statuses ctx changes =
  let open Deferred.Or_error.Let_syntax in
  let%bind () =
    List.filter_map changes ~f:(fun (name, status) ->
        let b = find_block ~test:ctx.test ctx.blocks name in
        Option.some_if
          (Status.equal b.status status)
          (sprintf "%s is %s already, which is not a change" name
             (Status.to_string status) ) )
    |> function
    | [] ->
        return ()
    | errors ->
        Deferred.Or_error.error_string (String.concat ~sep:"\n" errors)
  in
  let%bind got =
    with_conn ctx.db (fun (module Conn) ->
        Deferred.List.map ctx.blocks ~how:`Sequential ~f:(fun (b : block) ->
            Conn.find
              (Mina_caqti.find_req Caqti_type.int Caqti_type.string
                 "SELECT chain_status::text FROM blocks WHERE id = ?" )
              (ctx.id b.name)
            |> Deferred.Result.map ~f:(fun s -> (b, Status.of_string s)) )
        |> Deferred.map ~f:Result.all )
  in
  List.filter_map got ~f:(fun ((b : block), got) ->
      let want =
        List.Assoc.find changes b.name ~equal:String.equal
        |> Option.value ~default:b.status
      in
      Option.some_if
        (not (Status.equal want got))
        (sprintf "%s: expected %s, got %s" b.name (Status.to_string want)
           (Status.to_string got) ) )
  |> function
  | [] ->
      return ()
  | errors ->
      Deferred.Or_error.error_string (String.concat ~sep:"\n" errors)

(** {1 Test cases} *)

(* A database name for the test case: PostgreSQL keeps 63 bytes of a name,
   so a long case name is cut and told apart by a digest of the full one. *)
let db_name ~group name =
  let full = group ^ " " ^ name in
  let words =
    String.map full ~f:(fun c ->
        if Char.is_alphanum c then Char.lowercase c else '_' )
  in
  sprintf "test_%s_%s" (String.prefix words 40)
    (String.prefix (Md5.to_hex (Md5.digest_string full)) 8)

(** Build [blocks] into a fresh database, in order (a parent before its
    children), and run [f] on it. *)
let with_archive ~server_uri ~group ~name blocks f =
  let s = B.create () in
  let built = String.Table.create () in
  let state_hash block = real_state_hash (name ^ ": " ^ block) in
  let built_block block =
    match Hashtbl.find built block with
    | Some b ->
        b
    | None ->
        failwithf "%s: block %s is used before it is listed" name block ()
  in
  List.iter blocks ~f:(fun (b : block) ->
      let parent, parent_hash =
        match b.parent with
        | `Linked p ->
            (Some (built_block p), None)
        | `Unlinked p ->
            (None, Some (state_hash p))
        | `Not_in_archive ->
            (None, None)
      in
      Hashtbl.add_exn built ~key:b.name
        ~data:
          (B.block ~state_hash:(state_hash b.name) ?parent ?parent_hash
             ?global_slot_since_genesis:b.global_slot_since_genesis
             ?global_slot_since_hard_fork:b.global_slot_since_hard_fork
             ~protocol_version:b.protocol_version s ~name:b.name
             ~height:b.height b.status ) ) ;
  B.Db.with_fresh ~server_uri ~name:(db_name ~group name) (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind materialized = B.materialize s db in
      f
        { db
        ; test = name
        ; blocks
        ; id = (fun block -> B.block_id materialized (built_block block))
        ; state_hash
        ; public_key = (fun account -> B.public_key (B.account s account))
        } )

(** An Alcotest test case [name] of [group]: [f] on the archive of
    [blocks]. *)
let test ~server_uri ~group ~name blocks f =
  ( name
  , `Quick
  , fun () ->
      Thread_safe.block_on_async_exn (fun () ->
          with_archive ~server_uri ~group ~name blocks f )
      |> Or_error.ok_exn )
