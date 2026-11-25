(** Provides common aliases to provide a single entrypoint to open in Vinegar
    libraries
*)

(** [B] is [Bignum.Bigint] *)
module B = Bigint

(** {2 Import from {module:Composition_types}} *)

module Types = Composition_types
module Digest = Types.Digest
module Spec = Types.Spec
module Branch_data = Types.Branch_data
module Step_bp_vec = Types.Step_bp_vec
module Nvector = Types.Nvector
module Bulletproof_challenge = Types.Bulletproof_challenge

(** {2 Import from library [Vinegar_base]} *)

module Domain = Vinegar_base.Domain
module Domains = Vinegar_base.Domains

(** {2 Misc modules}*)

module H_list = Snarky_backendless.H_list
module Challenge = Vinegar_limb_vector.Challenge
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge

(** {2 Values} *)

(** debug flag *)
val debug : bool
