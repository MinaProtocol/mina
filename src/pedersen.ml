open Core_kernel

module type S = sig
  type curve

  module Digest : sig
    type t [@@deriving bin_io]

    module Snarkable : functor (Impl : Snark_intf.S) ->
      Impl.Snarkable.Bits.S
      with type Packed.var = Impl.Cvar.t
       and type Packed.value = Impl.Field.t
  end

  module Params : sig
    type t = curve array

    val random : max_input_length:int -> t
  end

  module State : sig
    type t

    val create : Params.t ->  t

    val update : t -> Bigstring.t -> unit

    val digest : t -> Digest.t
  end
end

module Make
    (Field : Camlsnark.Field_intf.S)
    (Bigint : Camlsnark.Bigint_intf.Extended with type field := Field.t)
    (Curve : Camlsnark.Curves.Edwards.Basic.S with type field := Field.t) =
struct
  let (/^) x y = Float.(to_int (round_up (x // y)))

  let field_size_in_bytes = Field.size_in_bits /^ 8

(* Someday: There should be a more efficient way of doing
    this since bigints are backed by a char[] *)
  let field_to_bigstring x =
    let n = Bigint.of_field x in
    let b i j =
      if Bigint.test_bit n (i + j)
      then 1 lsl j
      else 0
    in
    Bigstring.init field_size_in_bytes ~f:(fun i ->
      Char.of_int_exn (
        b i 0
        lor b i 1
        lor b i 2
        lor b i 3
        lor b i 4
        lor b i 5
        lor b i 6
        lor b i 7))

  (* Someday:
     This/the reader can definitely be made more efficient as well.
     bin_read should probably be in C. *)
  let bigstring_to_field s =
    Bigstring.to_string ~len:field_size_in_bytes ~pos:0 s
    |> Bigint.of_numeral ~base:256
    |> Bigint.to_field

  (* TODO: Unit tests for field_to_bigstring/bigstring_to_field *)

  module Digest = struct
    type t = Field.t

    let ({ Bin_prot.Type_class.
           reader = bin_reader_t
         ; writer = bin_writer_t
         ; shape = bin_shape_t
         } as bin_t) =
      Bin_prot.Type_class.cnv Fn.id
        field_to_bigstring
        bigstring_to_field
        Bigstring.bin_t

    let { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ } = bin_reader_t
    let { Bin_prot.Type_class.write = bin_write_t; size = bin_size_t } = bin_writer_t

    (* TODO: Assert that main_curve modulus is smaller than other_curve *)
    let () = 
      let open Snark_params in
      assert
        (Main_curve.Field.size_in_bits = Other_curve.Field.size_in_bits)

    module Snarkable = Bits.Field_element
  end

  module Params = struct
    type t = Curve.t array

    let random_elt () =
      let x = Field.random () in
      let n = Bigint.of_field x in
      let rec go pt i acc =
        if i = Field.size_in_bits
        then acc
        else
          let acc =
            if Bigint.test_bit n i
            then Curve.add acc pt
            else acc
          in
          go (Curve.double pt) (i + 1) acc
      in
      go Curve.generator 0 Curve.identity
    ;;

    let random ~max_input_length =
      Array.init max_input_length ~f:(fun _ -> random_elt ())

    let max_input_length t = Array.length t
  end

  module State = struct
    type t =
      { mutable acc : Curve.t
      ; mutable i   : int
      ; params      : Params.t
      }

    let create params = { acc = Curve.identity; i = 0; params }

    let ith_bit_int n i =
      ((n lsr i) land 1) = 1

    let update (t : t) s =
      let byte_length = Bigstring.length s in
      let bit_length = 8 * byte_length in
      assert (bit_length <= Params.max_input_length t.params - t.i);
      let acc = ref t.acc in
      for i = 0 to byte_length - 1 do
        let c = Char.to_int (Bigstring.get s i) in
        let cond_add j acc =
          if ith_bit_int c j
          then Curve.add acc t.params.(i)
          else acc
        in
        acc :=
          !acc
          |> cond_add 0
          |> cond_add 1
          |> cond_add 2
          |> cond_add 3
          |> cond_add 4
          |> cond_add 5
          |> cond_add 6
          |> cond_add 7
      done;
      t.acc <- !acc;
      t.i   <- t.i + bit_length
    ;;

    let digest t = let (x, _y) = t.acc in x
  end
end

module Main = struct
  module Curve = struct
    include Snark_params.Main.Hash_curve

    module Scalar (Impl : Camlsnark.Snark_intf.S) = struct
      (* Someday: Make more efficient *)
      open Impl
      type var = Boolean.var list
      type value = bool list

      let length = bit_length
      let spec : (var, value) Var_spec.t = Var_spec.list ~length Boolean.spec
      let assert_equal = Checked.Assert.equal_bitstrings
    end
  end

  include Make(Snark_params.Main.Field)(Snark_params.Main_curve.Bigint.R)(Curve)

  let params = Pedersen_params.t

  let hash x : Digest.t =
    let s = State.create params in
    State.update s x;
    State.digest s
  ;;

  let zero_hash = hash (Bigstring.create 0)
end
