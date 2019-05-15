open Coda_base
open Signature_lib

include
  Intf.S
  with type time := Block_time.Time.Stable.V1.t
   and type transaction := User_command.Stable.V1.t

module For_tests : sig
  val populate_database :
    directory:string -> int -> int -> t * Public_key.Compressed.t list
end
