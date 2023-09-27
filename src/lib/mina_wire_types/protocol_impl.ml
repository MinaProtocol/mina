open Utils

module Types = struct
  module type S = V1S0
end

module type Concrete = sig
  module V1 : sig
    type t = { api : int; patch : int; tag : string option }
  end
end

module M = struct
  module V1 = struct
    type t = { api : int; patch : int; tag : string option }
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
