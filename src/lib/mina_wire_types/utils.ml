(** Various useful module types and functors *)

(** The signature of a module *)
module type Single_sig = sig
  module type S
end

(** Signature maker provided by implementation module *)
module Signature (Types : Single_sig) = struct
  module type S = functor (_ : Types.S) -> Single_sig
end

(** {2 Types of modules with a single type [t] of different arities} *)

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

module type S4 = sig
  type ('a, 'b, 'c, 'd) t
end

module type S8 = sig
  type ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) t
end

(** {2 Same, for versioned types} *)

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

module type V1S4 = sig
  module V1 : S4
end

module type V1S8 = sig
  module V1 : S8
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
