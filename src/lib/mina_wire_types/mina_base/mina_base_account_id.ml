open Utils

module Types = struct
  module type S = sig
    module Digest : V1S0

    include V2S0
  end
end

module type Concrete =
  Types.S
    with type Digest.V1.t = Pickles.Backend.Tick.Field.V1.t
     and type V2.t =
      Public_key.Compressed.V1.t * Pickles.Backend.Tick.Field.V1.t

module M = struct
  module Digest = struct
    module V1 = struct
      type t = Pickles.Backend.Tick.Field.V1.t
    end
  end

  module V2 = struct
    type t = Public_key.Compressed.V1.t * Pickles.Backend.Tick.Field.V1.t
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
