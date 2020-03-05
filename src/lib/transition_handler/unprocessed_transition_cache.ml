(* The unprocessed transition cache is a cache of transitions which have been
 * ingested from the network but have not yet been processed into the transition
 * frontier. This is used in order to drop duplicate transitions which are still
 * being handled by various threads in the transition frontier controller. *)

open Core_kernel
open Coda_base
open Coda_transition
open Network_peer

module Name = struct
  let t = __MODULE__
end

module Transmuter = struct
  module Source = struct
    type t = External_transition.Initial_validated.t Envelope.Incoming.t
  end

  module Target = State_hash

  let transmute enveloped_transition =
    let {With_hash.hash; data= _}, _ =
      Envelope.Incoming.data enveloped_transition
    in
    hash
end

module Registry = struct
  type element = State_hash.t

  let element_added _ =
    Coda_metrics.(
      Gauge.inc_one Transition_frontier_controller.transitions_being_processed)

  let element_removed _ _ =
    Coda_metrics.(
      Gauge.dec_one Transition_frontier_controller.transitions_being_processed)
end

include Cache_lib.Transmuter_cache.Make (Transmuter) (Registry) (Name)
