module Kimchi_backend_common : sig
  module Field : sig
    module type S = sig
      type t

      val to_yojson : t -> Yojson.Safe.t

      val of_yojson : Yojson.Safe.t -> t Ppx_deriving_yojson_runtime.error_or

      val t_of_sexp : Sexplib0.Sexp.t -> t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      val compare : t -> t -> int

      val bin_size_t : t Bin_prot.Size.sizer

      val bin_write_t : t Bin_prot.Write.writer

      val bin_read_t : t Bin_prot.Read.reader

      val __bin_read_t__ : (int -> t) Bin_prot.Read.reader

      val bin_shape_t : Bin_shape_lib.Bin_shape.t

      val bin_writer_t : t Bin_prot.Type_class.writer0

      val bin_reader_t : t Bin_prot.Type_class.reader0

      val bin_t : t Bin_prot.Type_class.t0

      val hash_fold_t :
        Base_internalhash_types.state -> t -> Base_internalhash_types.state

      val hash : t -> Ppx_hash_lib.Std.Hash.hash_value

      module Bigint : Kimchi_backend_common__.Bigint.Intf

      val to_bigint : t -> Bigint.t

      val of_bigint : Bigint.t -> t

      val of_int : int -> t

      val add : t -> t -> t

      val sub : t -> t -> t

      val mul : t -> t -> t

      val div : t -> t -> t

      val negate : t -> t

      val square : t -> t

      val is_square : t -> bool

      val equal : t -> t -> bool

      val print : t -> unit

      val to_string : t -> string

      val of_string : string -> t

      val random : unit -> t

      val rng : int -> t

      val two_adic_root_of_unity : unit -> t

      val mut_add : t -> t -> unit

      val mut_mul : t -> t -> unit

      val mut_square : t -> unit

      val mut_sub : t -> t -> unit

      val copy : t -> t -> unit

      val to_bytes : t -> bytes

      val of_bytes : bytes -> t

      module Vector : sig
        type elt = t

        type t

        val create : unit -> t

        val get : t -> int -> elt

        val set : t -> int -> elt -> unit

        val emplace_back : t -> elt -> unit

        val length : t -> int
      end

      val size : Bigint.t

      val domain_generator : log2_size:int -> t

      val one : t

      val zero : t

      val inv : t -> t

      val sqrt : t -> t

      val size_in_bits : int

      val to_bits : t -> bool list

      val of_bits : bool list -> t

      val ( + ) : t -> t -> t

      val ( - ) : t -> t -> t

      val ( * ) : t -> t -> t

      val ( / ) : t -> t -> t

      module Mutable : sig
        val add : t -> other:t -> unit

        val mul : t -> other:t -> unit

        val square : t -> unit

        val sub : t -> other:t -> unit

        val copy : over:t -> t -> unit
      end

      val ( += ) : t -> t -> unit

      val ( *= ) : t -> t -> unit

      val ( -= ) : t -> t -> unit
    end
  end

  module Scalar_challenge = Kimchi_backend_common.Scalar_challenge
end

module Pasta : sig
  module Basic : sig
    module Bigint256 = Kimchi_pasta.Basic.Bigint256
    module Fp = Kimchi_pasta.Basic.Fp
  end
end

module Field = Kimchi_backend_common.Field

(** Instantiations of Snarky with the pasta curves. *)
module Snarky : sig
  module Tick : sig
    val field_size : Pasta_bindings.BigInt256.t

    module Inner_curve = Kimchi_pasta.Pasta.Pallas
    module Field = Kimchi_pasta_basic.Fp
    module Curve = Kimchi_pasta_basic.Vesta
    module Bigint = Kimchi_pasta.Vesta_based_plonk.Bigint
    module Verification_key = Kimchi_pasta.Vesta_based_plonk.Verification_key
    module Rounds_vector = Kimchi_pasta_basic.Rounds.Step_vector
    module Rounds = Kimchi_pasta_basic.Rounds.Step
    module Keypair = Kimchi_pasta.Vesta_based_plonk.Keypair
    module Proof = Kimchi_pasta.Vesta_based_plonk.Proof
    module Proving_key = Kimchi_pasta.Vesta_based_plonk.Proving_key
    module Oracles = Kimchi_pasta.Vesta_based_plonk.Oracles
  end

  module Tock : sig
    val field_size : Pasta_bindings.BigInt256.t

    module Inner_curve = Kimchi_pasta.Pasta.Vesta
    module Field = Kimchi_pasta_basic.Fq
    module Curve = Kimchi_pasta_basic.Pallas
    module Bigint = Kimchi_pasta.Pallas_based_plonk.Bigint
    module Verification_key = Kimchi_pasta.Pallas_based_plonk.Verification_key
    module Rounds_vector = Kimchi_pasta_basic.Rounds.Wrap_vector
    module Rounds = Kimchi_pasta_basic.Rounds.Wrap
    module Keypair = Kimchi_pasta.Pallas_based_plonk.Keypair
    module Proof = Kimchi_pasta.Pallas_based_plonk.Proof
    module Proving_key = Kimchi_pasta.Pallas_based_plonk.Proving_key
    module Oracles = Kimchi_pasta.Pallas_based_plonk.Oracles
  end

  (** Instantiation of Snarky on the Tick / Step / Vesta curve. *)
  module Step :
      module type of
        Snarky_backendless.Snark.Run.Make (Kimchi_pasta.Vesta_based_plonk)

  (** Instantiation of Snarky on the Tock / Wrap / Pallas curve. *)
  module Wrap :
      module type of
        Snarky_backendless.Snark.Run.Make (Kimchi_pasta.Pallas_based_plonk)

  (** Monadic Instantiation of Snarky on the Tick / Step / Vesta curve. *)
  module Step_monad :
      module type of
        Snarky_backendless.Snark.Make (Kimchi_pasta.Vesta_based_plonk)

  (** Monadic Instantiation of Snarky on the Tock / Wrap / Pallas curve. *)
  module Wrap_monad :
      module type of
        Snarky_backendless.Snark.Make (Kimchi_pasta.Pallas_based_plonk)
end
