module Stable = Pickles.Side_loaded.Verification_key.Stable

type t = Pickles.Side_loaded.Verification_key.Stable.Latest.t

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Sexplib0.Sexp.t -> t

val sexp_of_t : t -> Sexplib0.Sexp.t

val equal : t -> t -> bool

val compare : t -> t -> int

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val dummy : t

val to_input :
  t -> (Pickles.Impls.Step.Field.Constant.t, bool) Random_oracle_input.t

module Checked = Pickles.Side_loaded.Verification_key.Checked

val typ :
  (Pickles.Side_loaded.Verification_key.Checked.t, t) Pickles.Impls.Step.Typ.t

module Max_branches = Pickles.Side_loaded.Verification_key.Max_branches
module Max_width = Pickles.Side_loaded.Verification_key.Max_width
