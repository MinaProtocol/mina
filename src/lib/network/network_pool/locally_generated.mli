type key = Mina_transaction.Transaction_hash.User_command_with_valid_signature.t

type value = Core_kernel.Time.t * [ `Batch of int ]

type t

val find_and_remove : t -> key -> value option

val add_exn : t -> key:key -> data:value -> unit

val mem : t -> key -> bool

val create : unit -> t

val update : t -> key -> f:(value option -> value) -> unit

val filteri_inplace : t -> f:(key:key -> data:value -> bool) -> unit

val to_alist : t -> (key * (Core_kernel.Time.t * [ `Batch of int ])) list

val iter_intersection : t -> t -> f:(key:key -> value -> value -> unit) -> unit

val iteri : t -> f:(key:key -> data:value -> unit) -> unit
