open Core_kernel

module type S = sig
  type 'a t = private 'a list

  include Container.S1 with type 'a t := 'a t

  val of_list : 'a list -> 'a t
end

module T = struct
  include List

  let of_list bs = bs
end

module Msb_first = struct
  include T

  let of_lsb_first = List.rev
end

module Lsb_first = struct
  include T

  let of_msb_first = List.rev
end
