(** {1 Verification Key - Pickles Verification Keys}

    This module defines the verification key structure for Pickles proofs.
    A verification key contains all the information needed to verify proofs
    without the proving key.

    {2 Structure}

    A verification key consists of:
    - {b commitments}: Polynomial commitments for the wrap circuit
    - {b index}: The kimchi verifier index with circuit structure
    - {b data}: Metadata including constraint count

    {2 Size}

    A verification key is approximately 2-3 KB, containing:
    - ~15 group elements (curve points) for polynomial commitments
    - Domain configuration (size, generator)
    - Feature flags (lookups, range checks, etc.)

    {2 Usage}

    The verification key is used:
    1. By the verifier to check proofs
    2. By step circuits that verify wrap proofs (absorbed into sponge)
    3. For key caching and storage

    @see {!Proof} for the proof types verified by this key
    @see {!Compile} for generating verification keys
*)

(** Metadata about the circuit. *)
module Data : sig
  module Stable : sig
    module V1 : sig
      type t = { constraints : int } [@@deriving yojson]

      include Plonkish_prelude.Sigs.VERSIONED
    end
  end

  type t = Stable.V1.t = { constraints : int } [@@deriving yojson]
end

module Stable : sig
  module V2 : sig
    type t =
      { commitments :
          Backend.Tock.Curve.Affine.t
          Pickles_types.Plonk_verification_key_evals.t
      ; index : Impls.Wrap.Verification_key.t
      ; data : Data.t
      }
    [@@deriving fields, to_yojson, of_yojson, bin_shape, bin_io]

    include Plonkish_prelude.Sigs.VERSIONED
  end

  module Latest = V2
end

type t = Stable.Latest.t =
  { commitments :
      Backend.Tock.Curve.Affine.t Pickles_types.Plonk_verification_key_evals.t
  ; index : Impls.Wrap.Verification_key.t
  ; data : Data.t
  }
[@@deriving fields, to_yojson, of_yojson]

val dummy_commitments : 'a -> 'a Pickles_types.Plonk_verification_key_evals.t

val dummy_step_commitments :
  'a -> ('a, 'a option) Pickles_types.Plonk_verification_key_evals.Step.t

val dummy : Stable.Latest.t lazy_t
