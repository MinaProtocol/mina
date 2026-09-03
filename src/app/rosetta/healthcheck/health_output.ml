(* The JSON records [rosetta-healthcheck ... --json] prints.

   These are the binary's machine-readable contract: an orchestrator
   reads them to decide whether a Rosetta instance is usable.  Each
   record therefore has a type here rather than being assembled field by
   field at the call site, so a probe cannot silently drop a field or
   rename one.

   Every optional field carries [@default None] (and every list
   [@default []]), which makes [to_yojson] omit it when it is absent.
   A probe that could not reach the server therefore emits
   [{"healthy":false,"error":"..."}] rather than a record padded with
   nulls. *)

(* One entry of /network/list's advertised set. *)
type network_id = { blockchain : string; network : string }
[@@deriving to_yojson]

(* [connectivity]: does /network/list answer, and does it advertise the
   network we were asked about? *)
type connectivity =
  { healthy : bool
  ; expected_network : string option [@default None]
  ; advertised : network_id list [@default []]
  ; error : string option [@default None]
  }
[@@deriving to_yojson]

(* [tip-recency]: how old is the tip /network/status reports?
   [max_age] is echoed back only when the tip failed the check, so the
   reader can see the bound that was applied. *)
type tip_recency =
  { healthy : bool
  ; block_height : int64 option [@default None]
  ; block_hash : string option [@default None]
  ; age_seconds : int64 option [@default None]
  ; max_age : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving to_yojson]

(* [ready] and [wait].  [timed_out] distinguishes "wait gave up" from
   "ready reported not-ready once"; [problems] lists one line per failed
   probe.

   There is no [error] field here, unlike the single-probe records: what
   would go in it is the [problems] list joined up, and a record that
   states the same failure twice invites a reader to wonder which one is
   authoritative.  [ready = false] marks the failure, [problems] says
   what it was. *)
type readiness =
  { ready : bool
  ; timed_out : bool option [@default None]
  ; block_height : int64 option [@default None]
  ; age_seconds : int64 option [@default None]
  ; problems : string list [@default []]
  }
[@@deriving to_yojson]

let connectivity_failed error =
  { healthy = false
  ; expected_network = None
  ; advertised = []
  ; error = Some error
  }

let tip_recency_failed error =
  { healthy = false
  ; block_height = None
  ; block_hash = None
  ; age_seconds = None
  ; max_age = None
  ; error = Some error
  }
