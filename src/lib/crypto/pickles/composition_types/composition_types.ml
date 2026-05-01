open Pickles_types
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
module Bulletproof_challenge = Bulletproof_challenge
module Branch_data = Branch_data
module Digest = Digest
module Spec = Spec
module Opt = Opt
module Wire = Wire
module Messages_for_next = Messages_for_next
module Reduced_messages_for_next = Reduced_messages_for_next
module Wrap_impl = Kimchi_pasta_snarky_backend.Wrap_impl

let index_to_field_elements =
  Pickles_base.Side_loaded_verification_key.index_to_field_elements

module Zero_values = Zero_values

module Wrap = Wrap_proof

module Step = Step_proof

module Nvector = Vector.With_length
module Wrap_bp_vec = Backend.Tock.Rounds_vector
module Step_bp_vec = Backend.Tick.Rounds_vector

module Challenges_vector = struct
  type 'n t = (Wrap_impl.Field.t Wrap_bp_vec.t, 'n) Vector.t

  module Constant = struct
    type 'n t = (Wrap_impl.Field.Constant.t Wrap_bp_vec.t, 'n) Vector.t
  end
end

(** Concrete (non-versioned) records mirroring
    [Pickles.Reduced_messages_for_next_proof_over_same_field].

    The versioned/[bin_io] type lives in
    [src/lib/crypto/pickles/reduced_messages_for_next_proof_over_same_field.ml].
    The records here are constrained equal to the corresponding
    [Mina_wire_types] skeleton so values flow freely between the two
    modules without conversion.

    Defining these records inside [Composition_types] lets consumers
    inline the [Step] / [Wrap] shapes directly instead of re-spelling
    them at every site. *)
