open Coda_base
open Coda_transition

module type S = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier : Coda_intf.Transition_frontier_intf
end

module With_unprocessed_transition_cache = struct
  module type S = sig
    include S

    module Unprocessed_transition_cache :
      Cache_lib.Intf.Transmuter_cache.S
      with module Cached := Cache_lib.Cached
       and module Cache := Cache_lib.Cache
       and type source =
                  External_transition.Initial_validated.t Envelope.Incoming.t
       and type target = State_hash.t
  end
end
