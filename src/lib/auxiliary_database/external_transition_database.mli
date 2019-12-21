open Coda_base

include
  Intf.External_transition
  with type filtered_external_transition := Filtered_external_transition.t
   and type time := Block_time.Stable.V1.t
   and type hash := State_hash.t
