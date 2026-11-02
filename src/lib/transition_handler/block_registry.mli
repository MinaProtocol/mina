(** The blocks the frontier controller is working on, from when the
    validator registers them until each has a terminal outcome. A block's
    outcome is decided once, by [finish], and finalizing its cache entry and
    answering its validation callback both follow from that outcome. Headers
    are registered too, for their callbacks; they have no cache entry, and are
    never added. *)

open Mina_base
open Network_peer

type t

(** A block's terminal outcome.
    - [`Added]: added to the frontier. Its callback is answered by whatever
      handles added blocks next, which decides whether to rebroadcast it.
    - [`Rejected]: invalid; its callback is answered [`Reject].
    - [`Ignored]: valid, or not known to be invalid, but not added; its
      callback is answered [`Ignore]. *)
type outcome = [ `Added | `Rejected | `Ignored ]

val create : logger:Logger.t -> cache_exceptions:bool -> t

(** The cache of registered blocks, for code that has yet to use the
    registry. *)
val cache : t -> Unprocessed_transition_cache.t

(** Register [block], to be answered through [valid_cb] when it finishes. *)
val register_exn :
     t
  -> Mina_block.initial_valid_block Envelope.Incoming.t
  -> valid_cb:Mina_net2.Validation_callback.t option
  -> ( Mina_block.initial_valid_block Envelope.Incoming.t
     , State_hash.t )
     Cache_lib.Cached.t

(** Finish the block that [cached] holds, or was transformed from, with
    [outcome]. A block that has already finished is left as it is. *)
val finish : t -> (_, State_hash.t) Cache_lib.Cached.t -> outcome -> unit

(** Finish the block that [cached] holds as added, and return its callback,
    for whatever handles added blocks to answer. A block that has already
    finished is left as it is, and has no callback to return. *)
val finish_added :
     t
  -> (_, State_hash.t) Cache_lib.Cached.t
  -> Mina_net2.Validation_callback.t option

(** Register [header], to be answered through [valid_cb] when it finishes. *)
val register_header :
     t
  -> Mina_block.initial_valid_header Envelope.Incoming.t
  -> valid_cb:Mina_net2.Validation_callback.t option
  -> unit

(** Finish the header with [state_hash], answering every callback it was
    registered with. A header that has already finished, or was never
    registered, is left as it is. *)
val finish_header : t -> State_hash.t -> [ `Rejected | `Ignored ] -> unit
