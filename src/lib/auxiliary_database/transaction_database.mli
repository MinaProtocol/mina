open Async
open Coda_base
open Signature_lib

include
  Intf.Transaction
  with type time := Block_time.Time.Stable.V1.t
   and type transaction :=
              ( Signed_command.Stable.V1.t
              , Transaction_hash.Stable.V1.t )
              With_hash.Stable.V1.t

module For_tests : sig
  val populate_database :
       directory:string
    -> num_wallets:int
    -> num_foreign:int
    -> int
    -> (t * Public_key.Compressed.t list * Public_key.Compressed.t list)
       Deferred.t
end
