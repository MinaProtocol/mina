open Coda_base
open Coda_transition

include
  Intf.External_transition
  with type external_transition := External_transition.Validated.t
   and type time := Block_time.t
   and type hash := State_hash.t
