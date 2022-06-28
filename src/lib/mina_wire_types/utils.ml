(** Signature maker provided by implentation module *)

module type Single_sig = sig
  module type S
end

module Signature (Types : Single_sig) = struct
  module type S = functor (_ : Types.S) -> Single_sig
end

module type S0 = sig
  type t
end
