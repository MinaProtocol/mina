(** The blocks the frontier controller is working on, from when the
    validator registers them until each has a terminal outcome. A block's
    outcome is decided once, by [finish], and finalizing its cache entry and
    answering its validation callback both follow from that outcome. *)

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
