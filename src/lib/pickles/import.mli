(** Provides common aliases to provide a single entrypoint to open in Pickles
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

(** {2 Import from library [Pickles_base]} *)

module Domain = Pickles_base.Domain
module Domains = Pickles_base.Domains

(** {2 Misc modules}*)

module H_list = Snarky_backendless.H_list
module Challenge = Limb_vector.Challenge
module Scalar_challenge = Kimchi_backend_common.Scalar_challenge

(** {2 Values} *)

(** debug flag *)
val debug : bool
