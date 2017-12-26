open Core_kernel

type t [@@deriving bin_io]

module Span : sig
  type t [@@deriving bin_io]

  val of_time_span : Time.Span.t -> t
end

val diff : t -> t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t
