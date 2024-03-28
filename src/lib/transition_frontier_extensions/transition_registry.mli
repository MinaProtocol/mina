open Async_kernel
open Mina_base

include Intf.Extension_intf with type view = unit

val register : t -> State_hash.t -> unit Deferred.t
