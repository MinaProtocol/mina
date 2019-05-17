open Coda_base

include
  Intf.S
  with type time := Block_time.Time.Stable.V1.t
   and type transaction := User_command.Stable.V1.t
