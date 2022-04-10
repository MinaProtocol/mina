type t = Snark_params.Tick.Field.t

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

val t_of_sexp : Sexplib0.Sexp.t -> t

val sexp_of_t : t -> Sexplib0.Sexp.t

val to_decimal_string : t -> string

val to_bytes : t -> string

val gen : t Core_kernel.Quickcheck.Generator.t

type var = Ledger_hash0.var

val var_to_hash_packed : var -> Random_oracle.Checked.Digest.t

val var_to_input :
     var
  -> ( Snark_params.Tick.Field.Var.t
     , Snark_params.Tick.Boolean.var )
     Random_oracle.Input.t

val var_to_bits :
  var -> (Snark_params.Tick.Boolean.var list, 'a) Snark_params.Tick.Checked.t

val typ : (var, t) Snark_params.Tick.Typ.t

val assert_equal : var -> var -> (unit, 'a) Snark_params.Tick.Checked.t

val equal_var :
  var -> var -> (Snark_params.Tick.Boolean.var, 'a) Snark_params.Tick.Checked.t

val var_of_t : t -> var

val fold : t -> bool Fold_lib.Fold.t

val size_in_bits : int

val iter : t -> f:(bool -> unit) -> unit

val to_bits : t -> bool list

val to_base58_check : t -> string

val of_base58_check : string -> t Base.Or_error.t

val of_base58_check_exn : string -> t

val to_input : t -> (t, bool) Random_oracle.Input.t

val ( >= ) : t -> t -> bool

val ( <= ) : t -> t -> bool

val ( = ) : t -> t -> bool

val ( > ) : t -> t -> bool

val ( < ) : t -> t -> bool

val ( <> ) : t -> t -> bool

val equal : t -> t -> bool

val min : t -> t -> t

val max : t -> t -> t

val ascending : t -> t -> int

val descending : t -> t -> int

val between : t -> low:t -> high:t -> bool

val clamp_exn : t -> min:t -> max:t -> t

val clamp : t -> min:t -> max:t -> t Base__.Or_error.t

type comparator_witness = Mina_base__Ledger_hash0.comparator_witness

val comparator : (t, comparator_witness) Base__.Comparator.comparator

val validate_lbound : min:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_ubound : max:t Base__.Maybe_bound.t -> t Base__.Validate.check

val validate_bound :
     min:t Base__.Maybe_bound.t
  -> max:t Base__.Maybe_bound.t
  -> t Base__.Validate.check

module Replace_polymorphic_compare =
  Mina_base__Ledger_hash0.Replace_polymorphic_compare
module Map = Mina_base__Ledger_hash0.Map
module Set = Mina_base__Ledger_hash0.Set

val compare : t -> t -> Core_kernel__.Import.int

val hash_fold_t :
  Ppx_hash_lib.Std.Hash.state -> t -> Ppx_hash_lib.Std.Hash.state

val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

val hashable : t Core_kernel__.Hashtbl.Hashable.t

module Table = Mina_base__Ledger_hash0.Table
module Hash_set = Mina_base__Ledger_hash0.Hash_set
module Hash_queue = Mina_base__Ledger_hash0.Hash_queue

val if_ :
     Snark_params.Tick.Boolean.var
  -> then_:var
  -> else_:var
  -> (var, 'a) Snark_params.Tick.Checked.t

val var_of_hash_packed : Random_oracle.Checked.Digest.t -> var

val of_hash : t -> t

module Stable = Mina_base__Ledger_hash0.Stable
