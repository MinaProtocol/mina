open Core_kernel

module type S = sig
  type data [@@deriving bin_io]
  type t [@@deriving bin_io]

  val sign : data -> t
  val data : t -> data option
end

