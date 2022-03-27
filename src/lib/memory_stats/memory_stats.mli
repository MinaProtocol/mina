val ocaml_memory_stats :
  unit -> (string * [> `Int of Core_kernel__.Import.int ]) list

val jemalloc_memory_stats : unit -> (string * [> `Int of int ]) list

val log_memory_stats : Logger.t -> process:string -> unit
