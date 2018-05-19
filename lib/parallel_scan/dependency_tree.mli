open Core_kernel

module Direction : sig
  type t =
    | Left
    | Right
  [@@deriving eq, bin_io]
end

module Dep_node : sig
  type 'a t =
    { data : 'a
    ; dep : ('a t * Direction.t) option
    }
  [@@deriving bin_io]
end

val build_dependency_map : parallelism_log_2:int -> int Dep_node.t Int.Table.t

