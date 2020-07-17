open Core_kernel

module type S = sig
  include Monad.S2

  val fail : 'e -> ('a, 'e) t
end
