(** Settle scenarios: a test case as data.

    A scenario names its test case, lists the blocks of a hand-built archive
    (by name, parents first), and the steps to run on it in order. Each step
    states what it expects:

    {[
      { name = "gap in the ended chain"
      ; blocks =
          [ block "A" ~height:1 Canonical
          ; block "B" ~parent:"A" ~height:2 Canonical
          ; block "C" ~parent:"B" ~height:3 Pending
          ; block "E" ~height:5 Pending (* its parent is not in the archive *)
          ; fork_genesis ~fork_block:"B" ~height:3 ()
          ]
      ; steps =
          [ Settle (settled 0 1)
          ; Expect [ ("C", Orphaned); ("E", Pending) ]
          ]
      }
    ]}

    {!test_case} turns a scenario into an Alcotest case that builds the
    archive into a fresh database and runs the steps. Shared by the archive's
    settle tests and the hardfork toolbox's convert-chain-to-canonical tests. *)

open Core
open Async
open Mina_base
module B = Synthetic_archive
module Settle = Archive_lib.Settle_pending_blocks

type status = B.chain_status = Canonical | Orphaned | Pending

let status_to_string = function
  | Canonical ->
      "canonical"
  | Orphaned ->
      "orphaned"
  | Pending ->
      "pending"

(** {1 Blocks} *)

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
    an earlier block of the scenario; without one, the block's parent is not
    in the archive. *)
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

(** {1 Steps} *)

(** The outcome a settle expects: the fork genesis it settles (by name) and
    what became of its boundary. *)
type outcome = { genesis : string option; boundary : Settle.boundary option }

(** [canonicalized] blocks made canonical, [orphaned] orphaned, at the fork
    genesis named [genesis]. *)
let settled ?(genesis = "genesis") canonicalized orphaned =
  { genesis = Some genesis
  ; boundary = Some (Settled { canonicalized; orphaned })
  }

(** The boundary of [genesis] could not be settled, for [reason]. *)
let unsettled ?(genesis = "genesis") reason =
  { genesis = Some genesis; boundary = Some reason }

(** No fork genesis: nothing to settle. *)
let no_fork = { genesis = None; boundary = None }

(** What a step can use: the database, and the scenario's blocks by name. *)
type ctx =
  { db : B.Db.t
  ; test : string  (** The test case's name. *)
  ; id : string -> int  (** A block's database id. *)
  ; state_hash : string -> string
  ; height : string -> int
  ; public_key : string -> string
        (** The public key of the scenario account of this name. *)
  }

type step =
  | Settle of outcome
      (** Settle_pending_blocks.run, as the archive and the toolbox do. *)
  | Dry_run of outcome  (** The same with [~dry_run:true]. *)
  | Mark of string
      (** The archive's canonical marking as the named block arrives
          (Processor.Block.update_chain_status), with k = 2. *)
  | Set_status of string * status
      (** E.g. a late block, which the archive stores as pending. *)
  | Expect of (string * status) list
      (** The named blocks have these chain statuses. *)
  | Expect_geneses of int * status list
      (** The chain statuses of the blocks at this height with global slot
          since hard fork 0, by id: the geneses the archive stored itself. *)
  | Sql of string  (** A statement run on the database. *)
  | Do of string * (ctx -> unit Deferred.Or_error.t)
      (** A step of the test's own, described. *)

type t = { name : string; blocks : block list; steps : step list }

(** {1 Running} *)

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

let mismatch what ~expected ~got =
  Or_error.errorf "%s:\n  expected: %s\n  got:      %s" what expected got

(** Compare a settle's result with [expected]. *)
let check_outcome ctx expected (got : Settle.t) =
  let want =
    { Settle.genesis_id = Option.map expected.genesis ~f:ctx.id
    ; boundary = expected.boundary
    }
  in
  if Settle.equal want got then Ok ()
  else
    mismatch "settle result"
      ~expected:(Sexp.to_string (Settle.sexp_of_t want))
      ~got:(Sexp.to_string (Settle.sexp_of_t got))

let show_statuses l =
  List.map l ~f:(fun (name, status) -> name ^ " " ^ status)
  |> String.concat ~sep:", "

let check_statuses ctx expected =
  let open Deferred.Or_error.Let_syntax in
  let%bind got =
    with_conn ctx.db (fun (module Conn) ->
        Deferred.List.map expected ~how:`Sequential ~f:(fun (name, _) ->
            Conn.find
              (Mina_caqti.find_req Caqti_type.int Caqti_type.string
                 "SELECT chain_status::text FROM blocks WHERE id = ?" )
              (ctx.id name)
            |> Deferred.Result.map ~f:(fun status -> (name, status)) )
        |> Deferred.map ~f:Result.all )
  in
  let expected =
    List.map expected ~f:(fun (name, status) -> (name, status_to_string status))
  in
  if [%equal: (string * string) list] expected got then return ()
  else
    Deferred.return
      (mismatch "chain statuses" ~expected:(show_statuses expected)
         ~got:(show_statuses got) )

let check_geneses ctx height expected =
  let open Deferred.Or_error.Let_syntax in
  let%bind got =
    with_conn ctx.db (fun (module Conn) ->
        Conn.collect_list
          (Mina_caqti.collect_req Caqti_type.int Caqti_type.string
             "SELECT chain_status::text FROM blocks WHERE height = ? AND \
              global_slot_since_hard_fork = 0 ORDER BY id" )
          height )
  in
  let expected = List.map expected ~f:status_to_string in
  if [%equal: string list] expected got then return ()
  else
    Deferred.return
      (mismatch
         (sprintf "geneses at height %d" height)
         ~expected:(String.concat ~sep:", " expected)
         ~got:(String.concat ~sep:", " got) )

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

let settle ?dry_run ctx expected =
  let open Deferred.Or_error.Let_syntax in
  let%bind got = with_conn ctx.db (Settle.run ?dry_run) in
  Deferred.return (check_outcome ctx expected got)

let run_step ctx step =
  let described what result =
    Deferred.Or_error.tag result ~tag:(sprintf "step %s" what)
  in
  match step with
  | Settle expected ->
      described "settle" (settle ctx expected)
  | Dry_run expected ->
      described "dry run" (settle ~dry_run:true ctx expected)
  | Mark name ->
      described ("mark " ^ name) (mark_chain_status ctx name)
  | Set_status (name, status) ->
      described
        (sprintf "set %s %s" name (status_to_string status))
        (exec ctx
           (sprintf "UPDATE blocks SET chain_status = '%s' WHERE id = %d"
              (status_to_string status) (ctx.id name) ) )
  | Expect expected ->
      described "expect" (check_statuses ctx expected)
  | Expect_geneses (height, expected) ->
      described "expect geneses" (check_geneses ctx height expected)
  | Sql sql ->
      described sql (exec ctx sql)
  | Do (what, f) ->
      described what (f ctx)

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

(** Build [t]'s archive into a fresh database and run its steps. *)
let run ~server_uri ~group (t : t) =
  let s = B.create () in
  let by_name = String.Table.create () in
  let spec_of name =
    match List.find t.blocks ~f:(fun b -> String.equal b.name name) with
    | Some b ->
        b
    | None ->
        failwithf "%s: no block %s in the scenario" t.name name ()
  in
  let state_hash name = real_state_hash (t.name ^ ": " ^ name) in
  let built_block name =
    match Hashtbl.find by_name name with
    | Some b ->
        b
    | None ->
        failwithf "%s: block %s is used before it is listed" t.name name ()
  in
  List.iter t.blocks ~f:(fun (b : block) ->
      let parent, parent_hash =
        match b.parent with
        | `Linked p ->
            (Some (built_block p), None)
        | `Unlinked p ->
            (None, Some (state_hash p))
        | `Not_in_archive ->
            (None, None)
      in
      Hashtbl.add_exn by_name ~key:b.name
        ~data:
          (B.block ~state_hash:(state_hash b.name) ?parent ?parent_hash
             ?global_slot_since_genesis:b.global_slot_since_genesis
             ?global_slot_since_hard_fork:b.global_slot_since_hard_fork
             ~protocol_version:b.protocol_version s ~name:b.name
             ~height:b.height b.status ) ) ;
  B.Db.with_fresh ~server_uri ~name:(db_name ~group t.name) (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      let ctx =
        { db
        ; test = t.name
        ; id = (fun name -> B.block_id built (built_block name))
        ; state_hash
        ; height = (fun name -> (spec_of name).height)
        ; public_key = (fun name -> B.public_key (B.account s name))
        }
      in
      Deferred.Or_error.List.iter t.steps ~how:`Sequential ~f:(run_step ctx) )

(** [t] as an Alcotest test case of [group]. *)
let test_case ~server_uri ~group (t : t) =
  ( t.name
  , `Quick
  , fun () ->
      Thread_safe.block_on_async_exn (fun () -> run ~server_uri ~group t)
      |> Or_error.ok_exn )
