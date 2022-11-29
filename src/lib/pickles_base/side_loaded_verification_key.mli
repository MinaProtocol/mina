(* Module Side_loaded_verification_key *)

module Poly : sig
  module Stable : sig
    module V2 : sig
      type ('g, 'proofs_verified, 'vk) t =
            ( 'g
            , 'proofs_verified
            , 'vk )
            Mina_wire_types.Pickles_base.Side_loaded_verification_key.Poly.V2.t =
        { max_proofs_verified : 'proofs_verified
        ; wrap_index : 'g Pickles_types.Plonk_verification_key_evals.Stable.V2.t
        ; wrap_vk : 'vk option
        }
      [@@deriving hash]

      include
        Pickles_types.Sigs.Binable.S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) t

      include Pickles_types.Sigs.VERSIONED
    end

    module Latest = V2
  end

  type ('g, 'proofs_verified, 'vk) t =
        ('g, 'proofs_verified, 'vk) Stable.Latest.t =
    { max_proofs_verified : 'proofs_verified
    ; wrap_index : 'g Pickles_types.Plonk_verification_key_evals.t
    ; wrap_vk : 'vk option
    }
  [@@deriving hash]
end

val wrap_index_to_input :
     ('gs -> 'f array)
  -> 'gs Pickles_types.Plonk_verification_key_evals.t
  -> 'f Random_oracle_input.Chunked.t

val index_to_field_elements :
     'a Pickles_types.Plonk_verification_key_evals.t
  -> g:('a -> 'b Core_kernel.Array.t)
  -> 'b Core_kernel.Array.t

val to_input :
     field_of_int:(int -> 'a)
  -> ('a * 'a, Pickles_base__Proofs_verified.t, 'b) Poly.t
  -> 'a Random_oracle_input.Chunked.t

val max_log2_degree : int

val bits : len:int -> int -> bool list

module Repr : sig
  module Stable : sig
    module V2 : sig
      type 'g t =
        { max_proofs_verified : Proofs_verified.Stable.V1.t
        ; wrap_index : 'g Pickles_types.Plonk_verification_key_evals.Stable.V2.t
        }
      [@@deriving sexp, equal, compare, yojson]

      include Pickles_types.Sigs.Binable.S1 with type 'a t := 'a t

      val __versioned__ : unit
    end

    module Latest = V2
  end

  type 'g t = 'g Stable.Latest.t =
    { max_proofs_verified : Proofs_verified.t
    ; wrap_index : 'g Pickles_types.Plonk_verification_key_evals.t
    }
end

module Width : sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving sexp, equal, compare, hash, yojson]

      include Pickles_types.Sigs.Binable.S with type t := t

      val __versioned__ : unit
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp, equal, compare, hash, yojson]

  val of_int_exn : int -> t

  val to_int : t -> int

  val to_bits : t -> bool list

  val zero : t

  module Max = Pickles_types.Nat.N2

  module Max_vector : Pickles_types.Vector.With_version(Max).S

  module Max_at_most : sig
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, Max.n) Pickles_types.At_most.t
        [@@deriving sexp, equal, compare, hash, yojson]

        include Pickles_types.Sigs.Binable.S1 with type 'a t := 'a t

        val __versioned__ : unit
      end

      module Latest = V1
    end

    type 'a t = 'a Stable.Latest.t
    [@@deriving sexp, equal, compare, hash, yojson]
  end

  module Length : Pickles_types.Nat.Add.Intf_transparent
end

module Domains : sig
  module Stable : sig
    module V1 : sig
      type 'a t = { h : 'a }
      [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
    end
  end

  type 'a t = { h : 'a }
  [@@deriving sexp, equal, compare, hash, yojson, hlist, fields]
end

(** [Max_branches] is mostly an alias for {!Pickles_types.Nat.N8} *)
module Max_branches : sig
  type 'a plus_n = 'a Pickles_types.Nat.N7.plus_n Pickles_types.Nat.s

  type n = Pickles_types.Nat.z plus_n

  val eq : (n, n) Base.Type_equal.t

  val n : Pickles_types.Nat.z plus_n Pickles_types.Nat.nat

  val add :
       'm Pickles_types.Nat.nat
    -> 'm plus_n Pickles_types.Nat.nat
       * (Pickles_types.Nat.z plus_n, 'm, 'm plus_n) Pickles_types.Nat.Adds.t

  module Log2 = Pickles_types.Nat.N3
end
