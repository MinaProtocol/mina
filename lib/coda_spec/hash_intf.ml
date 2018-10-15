open Core_kernel
open Snark_params.Tick
open Fold_lib
open Tuple_lib
open Snark_bits

module Base = struct
  module type S = sig
    type t = private Pedersen.Digest.t
    [@@deriving bin_io, sexp, eq, compare, hash]

    val gen : t Quickcheck.Generator.t

    val to_bytes : t -> string

    val length_in_triples : int

    val ( = ) : t -> t -> bool

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, compare, eq, hash]

        include Hashable_binable with type t := t
      end
    end

    type var

    val var_of_hash_unpacked : Pedersen.Checked.Digest.Unpacked.var -> var

    val var_to_hash_packed : var -> Pedersen.Checked.Digest.var

    val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

    val typ : (var, t) Typ.t

    val assert_equal : var -> var -> (unit, _) Checked.t

    val equal_var : var -> var -> (Boolean.var, _) Checked.t

    val var_of_t : t -> var

    include Bits_intf.S with type t := t

    include Hashable.S with type t := t

    val fold : t -> bool Triple.t Fold.t
  end
end

module Full_size = struct
  module type S = sig
    include Base.S

    val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

    val var_of_hash_packed : Pedersen.Checked.Digest.var -> var

    val of_hash : Pedersen.Digest.t -> t
  end
end

module Small = struct
  module type S = sig
    include Base.S

    val var_of_hash_packed : Pedersen.Checked.Digest.var -> (var, _) Checked.t

    val of_hash : Pedersen.Digest.t -> t Or_error.t
  end
end

module Blockchain_state = struct
  module type S = Full_size.S
end

module Protocol_state = struct
  module type S = Full_size.S
end

module Ledger = struct
  module type S = Full_size.S
end

module Frozen_ledger = struct
  module type S = Full_size.S
end

module Ledger_builder = struct
  module type S = sig
    module Ledger_hash : Ledger.S

    type t

    module Stable : sig
      module V1 : sig
        type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]

        include Hashable_binable with type t := t
      end
    end

    val dummy : t

    include Hashable.S with type t := t
    include Snarkable.S with type value := t

    val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

    val length_in_triples : int

    val fold : t -> bool Triple.t Fold.t

    module Aux_hash : sig
      type t

      module Stable : sig
        module V1 : sig
          type nonrec t = t [@@deriving bin_io, sexp, eq, compare, hash]
        end
      end

      val of_bytes : string -> t

      val to_bytes : t -> string

      val dummy : t
    end

    val ledger_hash : t -> Ledger_hash.t

    val aux_hash : t -> Aux_hash.t

    val of_aux_and_ledger_hash : Aux_hash.t -> Ledger_hash.t -> t
  end
end
