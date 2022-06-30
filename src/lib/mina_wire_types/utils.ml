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

module type V1S0 = sig
  module V1 : S0
end

module type V2S0 = sig
  module V2 : S0
end
