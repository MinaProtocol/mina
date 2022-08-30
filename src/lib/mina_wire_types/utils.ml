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

module type S1 = sig
  type 'a t
end

module type S2 = sig
  type ('a, 'b) t
end

module type S3 = sig
  type ('a, 'b, 'c) t
end

module type V1S0 = sig
  module V1 : S0
end

module type V1S1 = sig
  module V1 : S1
end

module type V1S2 = sig
  module V1 : S2
end

module type V1S3 = sig
  module V1 : S3
end

module type V2S0 = sig
  module V2 : S0
end

module type V2S1 = sig
  module V2 : S1
end

module type V2S2 = sig
  module V2 : S2
end

module type V2S3 = sig
  module V2 : S3
end
