open Async_kernel
open Mina_base

include Intf.Extension_intf with type view = unit

type registration

val register : t -> State_hash.t -> registration

val wait : registration -> unit Deferred.t

val unregister : registration -> unit
