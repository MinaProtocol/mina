(* The unprocessed transition cache is a cache of transitions which have been
 * ingested from the network but have not yet been processed into the transition
 * frontier. This is used in order to drop duplicate transitions which are still
 * being handled by various threads in the transition frontier controller. *)

open Core_kernel
open Mina_base
open Mina_transition
open Network_peer

module Name = struct
  let t = __MODULE__
end

module Transmuter = struct
  module Source = struct
    type t = Mina_block.initial_valid_block Envelope.Incoming.t
  end

  module Target = State_hash

  let transmute enveloped_transition =
    let transition, _ = Envelope.Incoming.data enveloped_transition in
    State_hash.With_state_hashes.state_hash transition
end

module Registry = struct
  type element = State_hash.t

  let element_added _ =
    Mina_metrics.(
      Gauge.inc_one Transition_frontier_controller.transitions_being_processed)

  let element_removed _ _ =
    Mina_metrics.(
      Gauge.dec_one Transition_frontier_controller.transitions_being_processed)
end

include Cache_lib.Transmuter_cache.Make (Transmuter) (Registry) (Name)
