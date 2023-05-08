[%%import "/src/config.mlh"]

open Utils

module Types : sig
  module type S = sig
    module Digest : V1S0

    include V2S0
  end
end

[%%ifdef consensus_mechanism]

module type Concrete =
  Types.S
    with type Digest.V1.t = Pickles.Backend.Tick.Field.V1.t
     and type V2.t =
      Public_key.Compressed.V1.t * Pickles.Backend.Tick.Field.V1.t

[%%else]

module type Concrete =
  Types.S
    with type Digest.V1.t = Snark_params.Tick.Field.t
     and type V2.t = Public_key.Compressed.V1.t * Snark_params.Tick.Field.V1.t

[%%endif]

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module Digest = M.Digest and module V2 = M.V2
