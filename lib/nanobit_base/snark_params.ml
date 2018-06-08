open Core_kernel

module Tick_curve = Snarky.Backends.Mnt4
module Tock_curve = Snarky.Backends.Mnt6

module Extend (Impl : Snarky.Snark_intf.S) = struct
  include Impl

  module Snarkable = struct
    module type S = sig
      type var
      type value
      val typ : (var, value) Typ.t
    end

    module Bits = struct
      module type Lossy = Bits_intf.Snarkable.Lossy
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

      module type Faithful = Bits_intf.Snarkable.Faithful
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var

      module type Small = Bits_intf.Snarkable.Small
        with type ('a, 'b) typ := ('a, 'b) Typ.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
         and type comparison_result := Checked.comparison_result
    end
  end
end

module Tock = struct
  module Tock0 = Extend(Snarky.Snark.Make(Tock_curve))
  include (Tock0 : module type of Tock0 with module Proof := Tock0.Proof)

  module Proof = struct
    include Tock0.Proof

    (* TODO: Do at compile time *)
    let dummy =
      lazy begin
        let exposing = Data_spec.([ Typ.field ]) in
        let main x = assert_equal x x in
        let keypair = generate_keypair main ~exposing in
        prove (Keypair.pk keypair) exposing () main Field.one
      end
  end
end

module Tick = struct
  module Tick0 = Extend(Snarky.Snark.Make(Tick_curve))

  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Field = struct
    module T = struct
      include Tick0.Field
      let compare t1 t2 = Bigint.(compare (of_field t1) (of_field t2))

      let hash_fold_t s x =
        Bignum_bigint.hash_fold_t s
          Bigint.(to_bignum_bigint (of_field x))

      let hash = Hash.of_fold hash_fold_t
    end
    include T
    include Hashable.Make(T)

    include Field_bin.Make(Tick0.Field)(Tick_curve.Bigint.R)

    module Bits = Bits.Make_field(Tick0.Field)(Tick0.Bigint)

    let rec compare_bitstring xs0 ys0 =
      match xs0, ys0 with
      | true :: xs, true :: ys | false :: xs, false :: ys -> compare_bitstring xs ys
      | false :: xs, true :: ys -> `LT
      | true :: xs, false :: ys -> `GT
      | [], [] -> `EQ
      | _ :: _, [] | [], _ :: _ -> failwith "compare_bitstrings: Different lengths"

    let () = 
      let main_size_proxy = List.rev (unpack (negate one)) in
      let other_size_proxy = List.rev Tock.Field.(unpack (negate one)) in
      assert (compare_bitstring main_size_proxy other_size_proxy = `LT)
  end

  module Pedersen = struct
    module Curve = struct
      (* someday: Compute this from the number inside of ocaml *)
      let bit_length = 262

      include Snarky.Curves.Edwards.Basic.Make(Field)(struct
          (*
  Curve params:
  d = 20
  cardinality = 475922286169261325753349249653048451545124878135421791758205297448378458996221426427165320
  2^3 * 5 * 7 * 399699743 * 4252498232415687930110553454452223399041429939925660931491171303058234989338533 *)

          let d = Field.of_int 20
          let cofactor = Bignum_bigint.(of_int 8 * of_int 5 * of_int 7 * of_int 399699743)
          let order = Bignum_bigint.of_string "4252498232415687930110553454452223399041429939925660931491171303058234989338533"

          let generator = 
            let f s = Tick_curve.Bigint.R.(to_field (of_decimal_string s)) in
            f "327139552581206216694048482879340715614392408122535065054918285794885302348678908604813232",
            f "269570906944652130755537879906638127626718348459103982395416666003851617088183934285066554"
        end)

      module Scalar (Impl : Snarky.Snark_intf.S) = struct
        (* Someday: Make more efficient *)
        open Impl
        type var = Boolean.var list
        type value = Bignum_bigint.t

        let test_bit t i =
          Bignum_bigint.(shift_right t i land one = one)

        let pack bs =
          let pack_char bs =
            Char.of_int_exn
              (List.foldi bs ~init:0
                  ~f:(fun i acc b -> if b then acc lor (1 lsl i) else acc))
          in
          String.of_char_list (List.map ~f:pack_char (List.chunks_of ~length:8 bs))
          |> Z.of_bits
          |> Bignum_bigint.of_zarith_bigint

        let length = bit_length
        let typ : (var, value) Typ.t =
          Typ.(
            transport (list ~length Boolean.typ)
              ~there:(fun n -> List.init length ~f:(Z.testbit (Bignum_bigint.to_zarith_bigint n)))
              ~back:pack)

        let equal = Checked.equal_bitstrings

        let assert_equal = Checked.Assert.equal_bitstrings
      end
    end

    module P = Pedersen.Make(Field)(Tick_curve.Bigint.R)(Curve)
    include (P : module type of P with module Digest := P.Digest)
    module Digest = struct
      include Hashable.Make(Field)
      include P.Digest

      include Snarkable(Tick0)
    end

    let params =
      let f s =
        Tick_curve.Bigint.R.(to_field (of_decimal_string s))
      in
      Array.map Pedersen_params.t ~f:(fun (x, y) -> (f x, f y))

    let hash_bigstring x : Digest.t =
      let s = State.create params in
      State.update_bigstring s x
      |> State.digest
    ;;

    let%test_unit "hash_observationally_injective" =
      let gen =
        let open Quickcheck.Generator in
        let open Let_syntax in
        let%bind length = small_positive_int in
        let bits = list_with_length length Bool.gen in
        filter (both bits bits) ~f:(fun (x, y) -> x <> y)
      in
      let h bs = digest_fold (State.create params) (List.fold bs) in
      Quickcheck.test gen ~f:(fun (x, y) ->
        assert (not (Digest.(=) (h x) (h y))))

    let zero_hash = hash_bigstring (Bigstring.create 0)
  end

  module Scalar = Pedersen.Curve.Scalar(Tick0)

  module Hash_curve =
    Snarky.Curves.Edwards.Extend
      (Tick0)
      (Scalar)
      (Pedersen.Curve)

  module Signature_curve = Hash_curve

  let%test "generator-order-match" =
    let open Hash_curve in
    equal
      (scale Params.generator Params.order)
      identity

  module Pedersen_hash = Snarky.Pedersen.Make(Tick0)(struct
      include Hash_curve
      let cond_add = Checked.cond_add
    end)

  let hash_bits ~(init : Pedersen.State.t) x =
    Pedersen_hash.hash x ~params:Pedersen.params
      ~init:(init.bits_consumed, Hash_curve.var_of_value init.acc)

  let digest_bits ~init x =
    Checked.(hash_bits ~init x >>| Pedersen_hash.digest)

  module Util = Snark_util.Make(Tick0)
end

let ledger_depth = 3

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
