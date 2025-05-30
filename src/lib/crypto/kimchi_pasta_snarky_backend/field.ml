open Intf
open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint

module type Input_intf = sig
  type t

  module Bigint : Bigint.Intf

  val size : unit -> Bigint.t

  val size_in_bits : unit -> int

  val to_bigint : t -> Bigint.t

  val of_bigint : Bigint.t -> t

  val of_int : int -> t

  val domain_generator : int -> t

  val add : t -> t -> t

  val sub : t -> t -> t

  val mul : t -> t -> t

  val div : t -> t -> t

  val inv : t -> t option

  val negate : t -> t

  val square : t -> t

  val sqrt : t -> t option

  val is_square : t -> bool

  val compare : t -> t -> int

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

  val domain_generator : int -> t

  module Vector : Snarky_intf.Vector.S with type elt = t
end

module type S = sig
  type t [@@deriving sexp, compare, yojson, bin_io, hash]

  include Input_intf with type t := t

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

module type S_with_version = sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      [@@@with_all_version_tags]

      type t [@@deriving version, sexp, bin_io, compare, hash, equal]

      (** [to_yojson t] converts a field element to JSON.
          Returns a string in hexadecimal format with "0x" prefix. *)
      val to_yojson : t -> Yojson.Safe.t

      (** [of_yojson j] converts JSON to a field element.

          Accepted input formats:
          - `String with "0x" or "0X" prefix: Interpreted as a hexadecimal
            representation
          - `String without "0x" or "0X" prefix: Interpreted as a decimal
            representation

          Both formats do not allow values higher than the field modulus.
          An exception [Failure] is raised if it happens.
          The values are interpreted as unsigned integers in the decimal
          representation (not Montgomery).

          Errors:
          - Returns Error if [j] is not a string (e.g., it's an int, bool,
            array, etc.)
          - Returns Error if the string cannot be parsed as a valid number in
            the given format *)
      val of_yojson : Yojson.Safe.t -> (t, string) Result.t
    end
  end]

  include S with type t = Stable.Latest.t
end

module Make (F : Input_intf) :
  S_with_version
    with type Stable.V1.t = F.t
     and module Bigint = F.Bigint
     and module Vector = F.Vector = struct
  include F

  let size = size ()

  let size_in_bits = size_in_bits ()

  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      [@@@with_all_version_tags]

      type t = (F.t[@version_asserted]) [@@deriving version]

      let to_latest = Fn.id

      include
        Binable.Of_binable
          (Bigint)
          (struct
            type nonrec t = t

            let to_binable = to_bigint

            let of_binable = of_bigint
          end)

      include
        Sexpable.Of_sexpable
          (Bigint)
          (struct
            type nonrec t = t

            let to_sexpable = to_bigint

            let of_sexpable = of_bigint
          end)

      let to_bignum_bigint =
        let zero = of_int 0 in
        let one = of_int 1 in
        fun n ->
          if equal n zero then Bignum_bigint.zero
          else if equal n one then Bignum_bigint.one
          else
            Bytes.unsafe_to_string
              ~no_mutation_while_string_reachable:(to_bytes n)
            |> Z.of_bits |> Bignum_bigint.of_zarith_bigint

      let hash_fold_t s x = Bignum_bigint.hash_fold_t s (to_bignum_bigint x)

      let hash = Hash.of_fold hash_fold_t

      let compare = compare

      let equal = equal

      let to_yojson t : Yojson.Safe.t =
        `String (Bigint.to_hex_string (to_bigint t))

      let of_yojson j =
        match j with
        | `String s ->
            let parsed_bigint =
              if
                String.is_prefix ~prefix:"0x" s
                || String.is_prefix ~prefix:"0X" s
              then Bigint.of_hex_string s
              else Bigint.of_decimal_string s
            in
            Ok (of_bigint parsed_bigint)
        | _ ->
            Error "Expected a hex string or a decimal string"
    end
  end]

  include (
    Stable.Latest : module type of Stable.Latest with type t := Stable.Latest.t )

  let domain_generator ~log2_size = domain_generator log2_size

  let one = of_int 1

  let zero = of_int 0

  (* TODO: Improve snarky interface so these aren't necessary.. *)
  let inv x = Option.value (inv x) ~default:zero

  let sqrt x = Option.value (sqrt x) ~default:zero

  let to_bits t =
    (* Avoids allocation *)
    let n = F.to_bigint t in
    List.init size_in_bits ~f:(Bigint.test_bit n)

  let of_bits bs =
    List.fold (List.rev bs) ~init:zero ~f:(fun acc b ->
        let acc = add acc acc in
        if b then add acc one else acc )

  let ( + ) = add

  let ( - ) = sub

  let ( * ) = mul

  let ( / ) = div

  module Mutable = struct
    let add t ~other = mut_add t other

    let mul t ~other = mut_mul t other

    let square = mut_square

    let sub t ~other = mut_sub t other

    let copy ~over t = copy over t
  end

  let op f t other = f t ~other

  let ( += ) = op Mutable.add

  let ( *= ) = op Mutable.mul

  let ( -= ) = op Mutable.sub
end
