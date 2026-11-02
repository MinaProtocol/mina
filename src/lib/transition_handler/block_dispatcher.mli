(** The frontier controller's dispatcher: it handles the controller's events
    one at a time, in the order they arrive, without waiting on any. *)

open Mina_base
open Network_peer

(** A catchup job: the parent hash of a forest of blocks whose ancestry is
    missing, and the forest. *)
type catchup_job =
  State_hash.t
  * ( ( Mina_block.initial_valid_block Envelope.Incoming.t
      , State_hash.t )
      Cache_lib.Cached.t
    * Mina_net2.Validation_callback.t option )
    Mina_stdlib.Rose_tree.t
    list

(** A block or header the validator found relevant to the frontier. *)
type validated =
  [ `Block of
    ( Mina_block.initial_valid_block Envelope.Incoming.t
    , State_hash.t )
    Cache_lib.Cached.t
  | `Header of Mina_block.initial_valid_header Envelope.Incoming.t ]
  * [ `Valid_cb of Mina_net2.Validation_callback.t option ]

type event =
  | Validated of validated
  | Resume_catchup of (unit -> unit)
  | Catchup_job of catchup_job
  | Catchup_ready of (catchup_job -> unit)
      (** Super catchup has been set up, and handles jobs with this. *)

type t

(** Start a dispatcher that passes validated transitions to [on_validated].
    Catchup jobs that arrive before [Catchup_ready] are held, in order, and
    handled when it arrives. *)
val create : on_validated:(validated -> unit) -> t

val submit : t -> event -> unit

(** Pre-empt the dispatcher: validated transitions and catchup jobs it has
    yet to handle, including held jobs, are dropped, as are any submitted
    later. Catchup resumptions still run. This takes effect immediately rather
    than queueing behind events already submitted, because the frontier is
    closed as soon as the controller has been cleared. *)
val clear : t -> unit
