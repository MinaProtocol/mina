open Mina_base

module Entry : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        | Header of Mina_block.Header.Stable.V2.t
        | Invalid of
            { parent_state_hash : State_hash.Stable.V1.t
            ; blockchain_length : Mina_numbers.Length.Stable.V1.t
                  (* This field is set only if at the time of transition's
                     invalidation, body was present in block storage *)
            ; body_ref : Consensus.Body_reference.Stable.V1.t option
            }
      [@@deriving bin_io]
    end
  end]
end

type t

val iter :
     t
  -> f:
       (   State_hash.t
        -> Entry.t
        -> [< `Continue
           | `Remove_continue
           | `Remove_stop
           | `Stop
           | `Update_continue of Entry.t
           | `Update_stop of Entry.t ] )
  -> unit

val set : t -> State_hash.t -> Entry.t -> unit

val remove : t -> State_hash.t -> unit

val create : string -> t

val get : t -> State_hash.t -> Entry.t option
