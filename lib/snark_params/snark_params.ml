open Core_kernel
open Snark_bits
module Tick_curve = Crypto_params.Tick_curve
module Tock_curve = Crypto_params.Tock_curve

module Extend (Impl : Snarky.Snark_intf.S) = struct
  include Impl

  module Snarkable = struct
    module type S = sig
      type var

      type value

      val typ : (var, value) Typ.t
    end

    module Bits = struct
      module type Lossy =
        Bits_intf.Snarkable.Lossy
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

      module type Faithful =
        Bits_intf.Snarkable.Faithful
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

      module type Small =
        Bits_intf.Snarkable.Small
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
         and type comparison_result := Field.Checked.comparison_result
    end
  end
end

module Tock = struct
  module Tock0 = Extend (Snarky.Snark.Make (Tock_curve))

  include (Tock0 : module type of Tock0 with module Proof := Tock0.Proof)

  module Proof = struct
    include Tock0.Proof

    let dummy = Dummy_values.Tock.proof
  end
end

module Tick = struct
  module Tick0 = Extend (Crypto_params.Tick0)

  module Sha256 =
    Snarky.Sha256.Make (struct
        let prefix = Tick_curve.prefix
      end)
      (Tick0)
      (Tick_curve)

  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Inner_curve = struct
    open Tick0

    type var = Field.Checked.t * Field.Checked.t

    include Crypto_params.Inner_curve

    module Scalar = struct
      module T :
        module type of Tock.Field
        with type var := Tock.Field.var
         and module Checked := Tock.Field.Checked =
      Tock.Field

      include T
      include Infix

      let of_bits = Tock.Field.project

      let length_in_bits = size_in_bits

      type var = Boolean.var list

      let typ =
        Typ.transport
          (Typ.list ~length:size_in_bits Boolean.typ)
          ~there:unpack ~back:project

      let gen : t Quickcheck.Generator.t =
        Quickcheck.Generator.map
          (Bignum_bigint.gen_incl Bignum_bigint.one
             Bignum_bigint.(Tock.Field.size - one))
          ~f:(fun x -> Tock.Bigint.(to_field (of_bignum_bigint x)))

      let test_bit x i =
        Tock.Bigint.(test_bit (of_field x) i)

      module Checked = struct
        let equal = Bitstring_checked.equal

        module Assert = struct
          let equal = Bitstring_checked.Assert.equal
        end
      end
    end

    module Coefficients = Snarky.Libsnark.Curves.Mnt6.G1.Coefficients

    let find_y x =
      let y2 =
        Field.Infix.(x * Field.square x + Coefficients.a * x + Coefficients.b)
      in
      if Field.is_square y2
      then Some (Field.sqrt y2)
      else None

    let scale = scale_field

    module Checked = struct
      include Snarky.Curves.Make_weierstrass_checked (Tick0) (Scalar)
                (struct
                  include Crypto_params.Inner_curve

                  let scale = scale_field
                end)
                (Coefficients)

      let with_random_shift k =
        let open Let_syntax in
        let%bind init =
          provide_witness typ
            As_prover.(return (random ()))
        in
        let%bind shifted = k ~init in
        add shifted (negate init)

      let scale g s = with_random_shift (scale_bits g s)
      let scale_known g s = with_random_shift (scale_known g s)

      let add_known v x = add v (constant x)
    end

    let typ = Checked.typ
  end

  module Field = struct
    include Tick0.Field
    include Hashable.Make (Tick0.Field)
    module Bits = Bits.Make_field (Tick0.Field) (Tick0.Bigint)

    let size_in_triples = (size_in_bits + 2)/3

    let gen =
      Quickcheck.Generator.map
        Bignum_bigint.(gen_incl zero (Tick0.Field.size - one))
        ~f:(fun x -> Bigint.(to_field (of_bignum_bigint x)))

    let rec compare_bitstring xs0 ys0 =
      match (xs0, ys0) with
      | true :: xs, true :: ys | false :: xs, false :: ys ->
          compare_bitstring xs ys
      | false :: _, true :: _ -> `LT
      | true :: _, false :: _ -> `GT
      | [], [] -> `EQ
      | _ :: _, [] | [], _ :: _ ->
          failwith "compare_bitstrings: Different lengths"

    let () =
      let main_size_proxy = List.rev (unpack (negate one)) in
      let other_size_proxy = List.rev Tock.Field.(unpack (negate one)) in
      assert (compare_bitstring main_size_proxy other_size_proxy = `LT)
  end

  module Pedersen = struct
    include Crypto_params.Pedersen_params
    include Pedersen.Make (Field) (Bigint) (Inner_curve)

    let zero_hash = digest_fold (State.create params) (Fold_lib.Fold.of_list [(false, false, false)])

    module Checked = struct
      include
        Snarky.Pedersen.Make (Tick0) (Inner_curve)
          (Crypto_params.Pedersen_params)

      let hash_triples ts ~(init : State.t) =
        hash ts ~init:(init.triples_consumed, `Value init.acc)

      let digest_triples ts ~init =
        Checked.map (hash_triples ts ~init) ~f:digest
    end
  end

  module Util = Snark_util.Make (Tick0)
end

let embed (x: Tick.Field.t) : Tock.Field.t =
  let n = Tick.Bigint.of_field x in
  let rec go pt acc i =
    if i = Tick.Field.size_in_bits then acc
    else
      go (Tock.Field.add pt pt)
        (if Tick.Bigint.test_bit n i then Tock.Field.add pt acc else acc)
        (i + 1)
  in
  go Tock.Field.one Tock.Field.zero 0

let ledger_depth = 10

(* Let n = Tick.Field.size_in_bits.
   Let k = n - 3.
   The reason k = n - 3 is as follows. Inside [meets_target], we compare
   a value against 2^k. 2^k requires k + 1 bits. The comparison then unpacks
   a (k + 1) + 1 bit number. This number cannot overflow so it is important that
   k + 1 + 1 < n. Thus k < n - 2.

   However, instead of using `Field.size_in_bits - 3` we choose `Field.size_in_bits - 8`
   to clamp the easiness. To something not-to-quick on a personal laptop from mid 2010s.
*)
let target_bit_length = Tick.Field.size_in_bits - 8

module type Snark_intf = Snark_intf.S

module Test_util = struct
  open Fold_lib

  let triple_string trips =
    let to_string b = if b then "1" else "0" in
    String.concat ~sep:" "
      (List.map trips ~f:(fun (b1, b2, b3) -> to_string b1 ^ to_string b2 ^ to_string b3))

  let checked_to_unchecked typ1 typ2 checked =
    fun input ->
      let open Tick in
      let (), checked_result =
        Tick.run_and_check
          (let open Let_syntax in
          let%bind input = provide_witness typ1 (As_prover.return input) in
          let%map result = checked input in
          As_prover.read typ2 result)
          ()
        |> Or_error.ok_exn
      in
      checked_result
  ;;

  let test_to_triples typ fold var_to_triples input =
    let open Tick in
    let (), checked =
      Tick.run_and_check
        (let open Let_syntax in
        let%bind input = provide_witness typ (As_prover.return input) in
        let%map result = var_to_triples input in
        As_prover.all
          (List.map result
              ~f:(As_prover.read (Typ.tuple3 Boolean.typ Boolean.typ Boolean.typ))))
        ()
      |> Or_error.ok_exn
    in
    let unchecked = Fold.to_list (fold input) in
    if not (checked=unchecked )
    then failwithf
            !"Got %s (%d)\nexpected %s (%d)"
            (triple_string checked)
            (List.length checked)
            (triple_string unchecked)
            (List.length unchecked)
            ()
  ;;


  let test_equal ?(equal= ( = )) typ1 typ2 checked unchecked input =
    let open Tick in
    let checked_result = checked_to_unchecked typ1 typ2 checked input in
    assert (equal checked_result (unchecked input))

  let with_randomness r f =
    let s = Caml.Random.get_state () in
    Random.init r ;
    try
      let x = f () in
      Caml.Random.set_state s ; x
    with e -> Caml.Random.set_state s ; raise e
end

let%test_unit "pedersen checked/unchecked" =
  let thrice f x = f x x x in
  let gen = Quickcheck.Generator.(list (thrice tuple3 Bool.gen)) in
  Quickcheck.test gen ~f:(fun triples ->
    let n = List.length triples in
    let typ = Tick.Typ.list ~length:n (thrice Tick.Typ.tuple3 Tick.Boolean.typ) in
    let s = Tick.Pedersen.(State.create params) in
    Test_util.test_equal typ Tick.Pedersen.Checked.Digest.typ
      (Tick.Pedersen.Checked.digest_triples
         ~init:s)
      (fun xs -> Tick.Pedersen.digest_fold s (Fold_lib.Fold.of_list xs))
      triples)
