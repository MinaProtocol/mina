open Core_kernel

type allocation_info = {count: int}

val table : allocation_info String.Table.t

val attach_finalizer : string -> 'a -> 'a

val dump : unit -> Yojson.Safe.t
