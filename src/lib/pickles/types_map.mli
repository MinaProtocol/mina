type inner_curve_var =
  Backend.Tick.Field.t Snarky_backendless.Cvar.t
  * Backend.Tick.Field.t Snarky_backendless.Cvar.t

module Basic : sig
  type ('var, 'value, 'n1, 'n2) t =
    { max_proofs_verified : (module Pickles_types.Nat.Add.Intf with type n = 'n1)
    ; public_input : ('var, 'value) Impls.Step.Typ.t
    ; branches : 'n2 Pickles_types.Nat.t
    ; wrap_domains : Import.Domains.t
    ; wrap_key :
        Backend.Tick.Inner_curve.Affine.t
        Pickles_types.Plonk_verification_key_evals.t
    ; wrap_vk : Impls.Wrap.Verification_key.t
    ; step_uses_lookup : Pickles_types.Plonk_types.Opt.Flag.t
    }
end

module Side_loaded : sig
  module Ephemeral : sig
    type t =
      { index :
          [ `In_both of
            Side_loaded_verification_key.t
            * Side_loaded_verification_key.Checked.t
          | `In_circuit of Side_loaded_verification_key.Checked.t
          | `In_prover of Side_loaded_verification_key.t ]
      }
  end

  module Permanent : sig
    type ('var, 'value, 'n1, 'n2) t =
      { max_proofs_verified :
          (module Pickles_types.Nat.Add.Intf with type n = 'n1)
      ; public_input : ('var, 'value) Impls.Step.Typ.t
      ; step_uses_lookup : Pickles_types.Plonk_types.Opt.Flag.t
      ; branches : 'n2 Pickles_types.Nat.t
      }
  end

  type ('var, 'value, 'n1, 'n2) t =
    { ephemeral : Ephemeral.t option
    ; permanent : ('var, 'value, 'n1, 'n2) Permanent.t
    }

  type packed =
    | T : ('var, 'value, 'n1, 'n2) Tag.id * ('var, 'value, 'n1, 'n2) t -> packed

  val to_basic : ('a, 'b, 'c, 'd) t -> ('a, 'b, 'c, 'd) Basic.t
end

module Compiled : sig
  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) basic =
    { public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; proofs_verifieds : (int, 'branches) Pickles_types.Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; wrap_domains : Import.Domains.t
    ; step_domains : (Import.Domains.t, 'branches) Pickles_types.Vector.t
    ; step_uses_lookup : Pickles_types.Plonk_types.Opt.Flag.t
    }

  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) t =
    { branches : 'branches Pickles_types.Nat.t
    ; max_proofs_verified :
        (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
    ; proofs_verifieds : (int, 'branches) Pickles_types.Vector.t
          (* For each branch in this rule, how many predecessor proofs does it have? *)
    ; public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; wrap_key :
        Backend.Tick.Inner_curve.Affine.t
        Pickles_types.Plonk_verification_key_evals.t
        Lazy.t
    ; wrap_vk : Impls.Wrap.Verification_key.t Lazy.t
    ; wrap_domains : Import.Domains.t
    ; step_domains : (Import.Domains.t, 'branches) Pickles_types.Vector.t
    ; step_uses_lookup : Pickles_types.Plonk_types.Opt.Flag.t
    }
end

module For_step : sig
  type ('a_var, 'a_value, 'max_proofs_verified, 'branches) t =
    { branches : 'branches Pickles_types.Nat.t
    ; max_proofs_verified :
        (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
    ; proofs_verifieds :
        [ `Known of (Impls.Step.Field.t, 'branches) Pickles_types.Vector.t
        | `Side_loaded ]
    ; public_input : ('a_var, 'a_value) Impls.Step.Typ.t
    ; wrap_key : inner_curve_var Pickles_types.Plonk_verification_key_evals.t
    ; wrap_domain :
        [ `Known of Import.Domain.t
        | `Side_loaded of
          Impls.Step.field Pickles_base.Proofs_verified.One_hot.Checked.t ]
    ; step_domains :
        [ `Known of (Import.Domains.t, 'branches) Pickles_types.Vector.t
        | `Side_loaded ]
    ; step_uses_lookup : Pickles_types.Plonk_types.Opt.Flag.t
    }

  val of_side_loaded : ('a, 'b, 'c, 'd) Side_loaded.t -> ('a, 'b, 'c, 'd) t

  val of_compiled : ('a, 'b, 'c, 'd) Compiled.t -> ('a, 'b, 'c, 'd) t
end

type t

val univ : t

val lookup_compiled :
  ('var, 'value, 'n, 'm) Tag.id -> ('var, 'value, 'n, 'm) Compiled.t

val lookup_side_loaded :
  ('var, 'value, 'n, 'm) Tag.id -> ('var, 'value, 'n, 'm) Side_loaded.t

val lookup_basic :
  ('var, 'value, 'n, 'm) Tag.t -> ('var, 'value, 'n, 'm) Basic.t

val add_side_loaded :
     name:string
  -> ('a, 'b, 'c, 'd) Side_loaded.Permanent.t
  -> ('a, 'b, 'c, 'd) Tag.t

val max_proofs_verified :
     ('a, 'b, 'n1, 'c) Tag.t
  -> (module Pickles_types.Nat.Add.Intf with type n = 'n1)

val uses_lookup : _ Tag.t -> Pickles_types.Plonk_types.Opt.Flag.t

val add_exn :
  ('var, 'value, 'c, 'd) Tag.t -> ('var, 'value, 'c, 'd) Compiled.t -> unit

val set_ephemeral : _ Tag.t -> Side_loaded.Ephemeral.t -> unit

val public_input : ('var, 'value, _, _) Tag.t -> ('var, 'value) Impls.Step.Typ.t
