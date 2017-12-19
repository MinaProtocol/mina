open Core_kernel

type t [@@deriving bin_io]

module Span : sig
  type t [@@deriving bin_io]
end

val diff : t -> t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t
