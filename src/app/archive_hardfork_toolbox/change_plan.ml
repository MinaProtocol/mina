open Core

(* The change plan produced by convert-chain-to-canonical: a pure data
   description of what the operation would do, rendered either as a
   human-readable table or as JSON. It carries no database or presentation
   logic, so both renderers consume the exact same value. *)

module Block_ref = struct
  type t = { state_hash : string; height : int64; protocol_version : string }
  [@@deriving to_yojson]
end

module Fork_ref = struct
  type t =
    { state_hash : string (* the post-fork genesis block *)
    ; height : int64
    ; global_slot : int64 (* the boundary slot *)
    ; chain_status : string
    ; parent_state_hash : string option (* the last pre-fork block *)
    ; parent_height : int64 option
    }
  [@@deriving to_yojson]
end

module Summary = struct
  type t =
    { to_canonical : int (* blocks marked canonical (incl. already-canonical) *)
    ; to_canonical_pending : int (* of those, how many were pending (healed) *)
    ; to_orphaned : int (* blocks marked orphaned *)
    ; to_orphaned_pending : int (* of those, how many were pending *)
    }
  [@@deriving to_yojson]
end

module Change = struct
  type t =
    { height : int64
    ; state_hash : string
    ; current : string (* chain_status before the operation *)
    ; new_status : string [@key "new"] (* chain_status after the operation *)
    ; untouched : bool (* true when the block is left as-is (post-fork chain) *)
    ; reason : string (* why the block ends up with [new_status] *)
    }
  [@@deriving to_yojson]
end

type t =
  { dry_run : bool
  ; target : Block_ref.t (* last block that stays canonical *)
  ; fork_block : Fork_ref.t option (* the hard fork just above the target *)
  ; boundary_slot : int64 option (* blocks at/beyond this slot are untouched *)
  ; summary : Summary.t
  ; changes : Change.t list
        (* changing blocks, plus the fork block, by height *)
  }
[@@deriving to_yojson]

(* --- rendering --- *)

let marker_of t (change : Change.t) =
  let { Change.state_hash; _ } = change in
  let { Block_ref.state_hash = target_hash; _ } = t.target in
  if String.equal state_hash target_hash then "TARGET"
  else
    match t.fork_block with
    | Some { Fork_ref.state_hash = fork_hash; _ }
      when String.equal state_hash fork_hash ->
        "FORK BLOCK"
    | _ ->
        ""

let transition_of (change : Change.t) =
  let { Change.untouched; current; new_status; _ } = change in
  if untouched then sprintf "%s (untouched)" current
  else sprintf "%s → %s" current new_status

let render_header t =
  let { Block_ref.state_hash = target_hash
      ; height = target_height
      ; protocol_version
      } =
    t.target
  in
  printf "Target: %s (height %Ld), protocol version %s%s\n" target_hash
    target_height protocol_version
    (if t.dry_run then "  [DRY RUN]" else "") ;
  match t.fork_block with
  | Some { Fork_ref.state_hash; height; global_slot; parent_state_hash; _ } ->
      let parent_note =
        match parent_state_hash with
        | Some p when String.equal p target_hash ->
            " — its parent is the target"
        | Some p ->
            sprintf " — its parent is %s" p
        | None ->
            ""
      in
      printf "Fork block above target: %s (height %Ld, global slot %Ld)%s\n"
        state_hash height global_slot parent_note ;
      printf
        "Blocks at or beyond slot %Ld stay untouched, protecting the post-fork \
         chain.\n"
        global_slot
  | None ->
      printf
        "No hard fork above the target; the whole protocol version is in scope.\n"

let render_table t =
  let changing = List.count t.changes ~f:(fun c -> not c.Change.untouched) in
  if changing = 0 then
    printf
      "\nChange plan: nothing changes; chain already canonical to target.\n"
  else
    let columns =
      [ ("height", 7); ("transition", 23); ("reason", 44); ("state_hash", 52) ]
    in
    let rows =
      List.map t.changes ~f:(fun change ->
          let { Change.height; reason; state_hash; _ } = change in
          let cells =
            [ Int64.to_string height; transition_of change; reason; state_hash ]
          in
          let suffix =
            match marker_of t change with "" -> "" | m -> sprintf " ◀ %s" m
          in
          (cells, suffix) )
    in
    printf "\nChange plan — %d block(s) change:\n" changing ;
    printf "%s" (Utils.render_table ~columns rows)

let render_summary t =
  let { Summary.to_canonical
      ; to_canonical_pending
      ; to_orphaned
      ; to_orphaned_pending
      } =
    t.summary
  in
  let { Block_ref.protocol_version; _ } = t.target in
  printf
    "\n\
     Summary: %d → canonical (%d currently pending), %d of protocol version %s \
     → orphaned (%d currently pending).\n"
    to_canonical to_canonical_pending to_orphaned protocol_version
    to_orphaned_pending ;
  if t.dry_run then printf "Dry run: no changes were written.\n"

let render_human t = render_header t ; render_table t ; render_summary t

let render_json t =
  Yojson.Safe.pretty_to_channel Out_channel.stdout (to_yojson t) ;
  Out_channel.newline Out_channel.stdout
