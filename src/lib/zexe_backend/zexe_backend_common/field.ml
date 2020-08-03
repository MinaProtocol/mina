open Intf
open Core
open Snarky_bn382
module Bignum_bigint = Snarky.Backend_extended.Bignum_bigint

module type Input_intf = sig
  include Type_with_delete

  module Bigint : Bigint.Intf

  val size : unit -> Bigint.t

  val size_in_bits : unit -> int

  val to_bigint : t -> Bigint.t

  val of_bigint : Bigint.t -> t

  val to_bigint_raw : t -> Bigint.t

  val to_bigint_raw_noalloc : t -> Bigint.t

  val of_bigint_raw : Bigint.t -> t

  val of_int : Unsigned.UInt64.t -> t

  val add : t -> t -> t

  val sub : t -> t -> t

  val mul : t -> t -> t

  val div : t -> t -> t

  val inv : t -> t

  val negate : t -> t

  val square : t -> t

  val sqrt : t -> t

  val is_square : t -> bool

  val equal : t -> t -> bool

  val print : t -> unit

  val random : unit -> t

  val mut_add : t -> t -> unit

  val mut_mul : t -> t -> unit

  val mut_square : t -> unit

  val mut_sub : t -> t -> unit

  val copy : t -> t -> unit

  module Vector : sig
    include Snarky.Vector.S with type elt := t

    module Triple : Intf.Triple with type elt := t
  end
end

module type S = sig
  type t [@@deriving sexp, compare, yojson, bin_io, hash]

  module Bigint : Bigint.Intf

  val to_bigint : t -> Bigint.t

  val size : Bigint.t

  val to_bigint_raw_noalloc : t -> Bigint.t

  val of_bigint : Bigint.t -> t

  val of_int : int -> t

  val one : t

  val zero : t

  val add : t -> t -> t

  val sub : t -> t -> t

  val mul : t -> t -> t

  val div : t -> t -> t

  val inv : t -> t

  val square : t -> t

  val sqrt : t -> t

  val is_square : t -> bool

  val equal : t -> t -> bool

  val size_in_bits : int

  val to_bits : t -> bool list

  val of_bits : bool list -> t

  val print : t -> unit

  val random : unit -> t

  val negate : t -> t

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

  val delete : t -> unit

  module Vector : sig
    type elt = t

    type t

    val typ : t Ctypes.typ

    val delete : t -> unit

    val create : unit -> t

    val get : t -> int -> elt

    val emplace_back : t -> elt -> unit

    val length : t -> int

    val of_array : elt array -> t

    module Triple : Intf.Triple with type elt := t
  end
end

module type S_with_version = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version, sexp, bin_io, compare, yojson, hash, eq]
    end

    module Latest = V1
  end

  include S with type t = Stable.Latest.t
end

module Make (F : Input_intf) :
  S_with_version
  with type Stable.V1.t = F.t
   and module Bigint = F.Bigint
   and type Vector.t = F.Vector.t
   and type Vector.Triple.t = F.Vector.Triple.t = struct
  open F
  module Bigint = Bigint

  let size =
    let t = size () in
    Caml.Gc.finalise Bigint.delete t ;
    t

  let size_in_bits = size_in_bits ()

  let gc2 op x1 x2 =
    let r = op x1 x2 in
    Caml.Gc.finalise delete r ; r

  let gc1 op x1 =
    let r = op x1 in
    Caml.Gc.finalise delete r ; r

  let to_bigint x =
    let r = to_bigint x in
    Caml.Gc.finalise Bigint.delete r ;
    r

  let of_bigint = gc1 of_bigint

  let of_bigint_raw = gc1 of_bigint_raw

  let to_bigint_raw_noalloc = to_bigint_raw_noalloc

  module Stable = struct
    module V1 = struct
      type t = F.t [@@deriving version {asserted}]

      include Binable.Of_binable
                (Bigint)
                (struct
                  type nonrec t = t

                  let to_binable = to_bigint

                  let of_binable = of_bigint
                end)

      include Sexpable.Of_sexpable
                (Bigint)
                (struct
                  type nonrec t = t

                  let to_sexpable = to_bigint

                  let of_sexpable = of_bigint
                end)

      let to_bignum_bigint n =
        let rec go i two_to_the_i acc =
          if Int.equal i size_in_bits then acc
          else
            let acc' =
              if Bigint.test_bit n i then Bignum_bigint.(acc + two_to_the_i)
              else acc
            in
            go (i + 1) Bignum_bigint.(two_to_the_i + two_to_the_i) acc'
        in
        go 0 Bignum_bigint.one Bignum_bigint.zero

      let hash_fold_t s x =
        Bignum_bigint.hash_fold_t s (to_bignum_bigint (to_bigint x))

      let hash = Hash.of_fold hash_fold_t

      let compare t1 t2 = Bigint.compare (to_bigint t1) (to_bigint t2)

      let equal = equal

      let to_yojson t : Yojson.Safe.t =
        `String (Bigint.to_hex_string (to_bigint t))

      let of_yojson j =
        match j with
        | `String h ->
            Ok (of_bigint (Bigint.of_hex_string h))
        | _ ->
            Error "expected hex string"
    end

    module Latest = V1
  end

  include Stable.Latest

  let of_int = gc1 (Fn.compose of_int Unsigned.UInt64.of_int)

  let one = of_int 1

  let zero = of_int 0

  let add = gc2 add

  let sub = gc2 sub

  let mul = gc2 mul

  let div = gc2 div

  let inv = gc1 inv

  let square = gc1 square

  let sqrt = gc1 sqrt

  let is_square = is_square

  let to_bits t =
    (* Avoids allocation *)
    let n = F.to_bigint t in
    List.init size_in_bits ~f:(Bigint.test_bit n)

  let of_bits bs =
    List.fold (List.rev bs) ~init:zero ~f:(fun acc b ->
        let acc = add acc acc in
        if b then add acc one else acc )

  let print = print

  let random = gc1 random

  let%test_unit "sexp round trip" =
    let t = random () in
    assert (equal t (t_of_sexp (sexp_of_t t)))

  let%test_unit "bin_io round trip" =
    let t = random () in
    [%test_eq: Stable.Latest.t] t
      (Binable.of_string
         (module Stable.Latest)
         (Binable.to_string (module Stable.Latest) t))

  let negate = gc1 negate

  let ( + ) = add

  let ( - ) = sub

  let ( * ) = mul

  let ( / ) = div

  module Mutable = struct
    let add t ~other = mut_add t other

    let mul t ~other = mut_mul t other

    let square = mut_square

    let sub t ~other = mut_sub t other

    let copy ~over t = F.copy over t
  end

  let op f t other = f t ~other

  let ( += ) = op Mutable.add

  let ( *= ) = op Mutable.mul

  let ( -= ) = op Mutable.sub

  let delete = delete

  module Vector = struct
    type elt = t

    include Vector

    (* TODO: Leaky *)
    let of_array a =
      let t = create () in
      Array.iter a ~f:(emplace_back t) ;
      t
  end

  let%test "of_bits to_bits" =
    let x = random () in
    equal x (of_bits (to_bits x))

  let%test_unit "to_bits of_bits" =
    Quickcheck.test
      (Quickcheck.Generator.list_with_length
         Int.(size_in_bits - 1)
         Bool.quickcheck_generator)
      ~f:(fun bs -> [%test_eq: bool list] (bs @ [false]) (to_bits (of_bits bs)))
end
