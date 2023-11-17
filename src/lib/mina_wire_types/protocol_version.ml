open Utils

module Types = struct
  module type S = V2S0
end

module type Concrete = sig
  module V2 : sig
    type t = { transaction : int; network : int; patch : int }
  end
end

module M = struct
  module V2 = struct
    type t = { transaction : int; network : int; patch : int }
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
