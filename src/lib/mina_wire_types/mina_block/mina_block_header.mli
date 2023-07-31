open Utils

module Types : sig
  module type S = sig
    module V2 : S0
  end
end

module type Concrete = sig
  module V2 : sig
    type t =
      { protocol_state : Mina_state_protocol_state.Value.V2.t
      ; protocol_state_proof : Mina_base.Proof.V2.t
      ; delta_block_chain_proof :
          Data_hash_lib.State_hash.V1.t * Mina_base_state_body_hash.V1.t list
      ; current_protocol_version : Protocol_version.V1.t
      ; proposed_protocol_version_opt : Protocol_version.V1.t option
      }
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module V2 = M.V2
