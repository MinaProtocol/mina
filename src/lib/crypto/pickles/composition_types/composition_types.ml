open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Opt
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

let index_to_field_elements =
  Pickles_base.Side_loaded_verification_key.index_to_field_elements

module Zero_values = Zero_values
module Wire = Wire
module Messages_for_next = Messages_for_next
module Reduced_messages_for_next = Reduced_messages_for_next
module Wrap_plonk_iop = Wrap_plonk_iop
module Step_plonk_iop = Step_plonk_iop
module Step_deferred_values = Step_deferred_values
module Step_per_proof = Step_per_proof
module Step_proof = Step_proof
module Wrap_proof_state = Wrap_proof.Proof_state
module Wrap_statement = Wrap_proof.Statement
module Wrap_lookup_parameters = Wrap_proof.Lookup_parameters
module Step_proof_state = Step_proof.Proof_state
module Step_statement = Step_proof.Statement
module Step_bulletproof = Step_proof.Bulletproof
module Wrap = Wire.Wrap
module Step = Wire.Step
module Nvector = Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector

module Challenges_vector = struct
  type 'n t = (Wrap_impl.Field.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Wrap_impl.Field.Constant.t Wrap_bp_vec.t, 'n) Vector.t
  end
end
