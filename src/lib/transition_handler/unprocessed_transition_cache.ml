(* The unprocessed transition cache is a cache of transitions which have been
 * ingested from the network but have not yet been processed into the transition
 * frontier. This is used in order to drop duplicate transitions which are still
 * being handled by various threads in the transition frontier controller. *)

open Core_kernel
open Coda_base

module Name = struct
  let t = __MODULE__
end

module Transmuter = struct
  module Make (Inputs : Inputs.S) :
    Cache_lib.Intf.Transmuter.S
    with type Source.t =
                ( Consensus.External_transition.Verified.t
                , State_hash.t )
                With_hash.t
     and type Target.t = State_hash.t = struct
    module Source = struct
      type t =
        (Consensus.External_transition.Verified.t, State_hash.t) With_hash.t
    end

    module Target = State_hash

    let transmute = With_hash.hash
  end
end

module Make (Inputs : Inputs.S) :
  Cache_lib.Intf.Transmuter_cache.S
  with module Cached := Cache_lib.Cached
   and module Cache := Cache_lib.Cache
   and type source =
              (Consensus.External_transition.Verified.t, State_hash.t) With_hash.t
   and type target = State_hash.t =
  Cache_lib.Transmuter_cache.Make (Transmuter.Make (Inputs)) (Name)
