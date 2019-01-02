type 'v t = private 'v

module Unsafe : sig
  val create : 'v -> 'v t
end
