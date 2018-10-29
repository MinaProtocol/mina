open Core_kernel
open Fold_lib

(* Someday: Make more efficient by giving Field.unpack a length argument in
camlsnark *)
let unpack_field unpack ~bit_length x = List.take (unpack x) bit_length

let bits_per_char = 8

module Vector = struct
  module type Basic = sig
    type t

    val length : int

    val get : t -> int -> bool
  end

  module type S = sig
    include Basic

    val empty : t

    val set : t -> int -> bool -> t
  end

  module UInt64 : S with type t = Unsigned.UInt64.t = struct
    open Unsigned.UInt64.Infix
    include Unsigned.UInt64

    let length = 64

    let empty = zero

    let get t i = (t lsr i) land one = one

    let set t i b = if b then t lor (one lsl i) else t land lognot (one lsl i)
  end

  module UInt32 : S with type t = Unsigned.UInt32.t = struct
    open Unsigned.UInt32.Infix
    include Unsigned.UInt32

    let length = 32

    let empty = zero

    let get t i = (t lsr i) land one = one

    let set t i b = if b then t lor (one lsl i) else t land lognot (one lsl i)
  end

  module Make (V : Basic) : Bits_intf.S with type t = V.t = struct
    type t = V.t

    let fold t =
      { Fold.fold=
          (fun ~init ~f ->
            let rec go acc i =
              if i = V.length then acc else go (f acc (V.get t i)) (i + 1)
            in
            go init 0 ) }

    let iter t ~f =
      for i = 0 to V.length - 1 do
        f (V.get t i)
      done

    let to_bits t = List.init V.length ~f:(V.get t)
  end

  module Bigstring (M : sig
    val bit_length : int
  end) : Basic with type t = Bigstring.t = struct
    type t = Bigstring.t

    let char_nth_bit c n = (Char.to_int c lsl n) land 1 = 1

    let get t n =
      char_nth_bit (Bigstring.get t (n / bits_per_char)) (n mod bits_per_char)

    let length = M.bit_length
  end
end

module UInt64 : Bits_intf.S with type t := Unsigned.UInt64.t =
  Vector.Make (Vector.UInt64)

module UInt32 : Bits_intf.S with type t := Unsigned.UInt32.t =
  Vector.Make (Vector.UInt32)

module Make_field0
    (Field : Snarky.Field_intf.S)
    (Bigint : Snarky.Bigint_intf.S with type field := Field.t) (M : sig
        val bit_length : int
    end) : Bits_intf.S with type t = Field.t = struct
  open M

  type t = Field.t

  let fold t =
    { Fold.fold=
        (fun ~init ~f ->
          let n = Bigint.of_field t in
          let rec go acc i =
            if i = bit_length then acc
            else go (f acc (Bigint.test_bit n i)) (i + 1)
          in
          go init 0 ) }

  let iter t ~f =
    let n = Bigint.of_field t in
    for i = 0 to bit_length - 1 do
      f (Bigint.test_bit n i)
    done

  let to_bits t =
    let n = Bigint.of_field t in
    let rec go acc i =
      if i < 0 then acc else go (Bigint.test_bit n i :: acc) (i - 1)
    in
    go [] (bit_length - 1)
end

module Make_field
    (Field : Snarky.Field_intf.S)
    (Bigint : Snarky.Bigint_intf.S with type field := Field.t) :
  Bits_intf.S with type t = Field.t =
  Make_field0 (Field) (Bigint)
    (struct
      let bit_length = Field.size_in_bits
    end)

module Small
    (Field : Snarky.Field_intf.S)
    (Bigint : Snarky.Bigint_intf.S with type field := Field.t) (M : sig
        val bit_length : int
    end) : Bits_intf.S with type t = Field.t = struct
  let () = assert (M.bit_length < Field.size_in_bits)

  include Make_field0 (Field) (Bigint) (M)
end

module Snarkable = struct
  module Small_bit_vector
      (Impl : Snarky.Snark_intf.S) (V : sig
          type t

          val empty : t

          val length : int

          val get : t -> int -> bool

          val set : t -> int -> bool -> t
      end) :
    Bits_intf.Snarkable.Small
    with type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
     and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
     and type boolean_var := Impl.Boolean.var
     and type Packed.var = Impl.Field.Checked.t
     and type Packed.value = V.t
     and type Unpacked.var = Impl.Boolean.var list
     and type Unpacked.value = V.t
     and type comparison_result := Impl.Field.Checked.comparison_result =
  struct
    open Impl

    let bit_length = V.length

    let () = assert (bit_length < Field.size_in_bits)

    let init ~f =
      let rec go acc i =
        if i = V.length then acc else go (V.set acc i (f i)) (i + 1)
      in
      go V.empty 0

    module Packed = struct
      type var = Field.Checked.t

      type value = V.t

      let typ : (var, value) Typ.t =
        let open Typ in
        let read v =
          let open Read.Let_syntax in
          let%map x = Read.read v in
          let n = Bigint.of_field x in
          init ~f:(fun i -> Bigint.test_bit n i)
        in
        let store t =
          let open Store.Let_syntax in
          let rec go two_to_the_i i acc =
            if i = V.length then acc
            else
              let acc =
                if V.get t i then Field.add two_to_the_i acc else acc
              in
              go (Field.add two_to_the_i two_to_the_i) (i + 1) acc
          in
          Store.store (go Field.one 0 Field.zero)
        in
        let alloc = Alloc.alloc in
        let check _ = Checked.return () in
        {read; store; alloc; check}
    end

    let v_to_list n v =
      List.init n ~f:(fun i -> if i < V.length then V.get v i else false)

    let v_of_list vs =
      List.foldi vs ~init:V.empty ~f:(fun i acc b ->
          if i < V.length then V.set acc i b else acc )

    let pack_var = Field.Checked.project

    let pack_value = Fn.id

    module Unpacked = struct
      type var = Boolean.var list

      type value = V.t

      let typ : (var, value) Typ.t =
        Typ.transport
          (Typ.list ~length:V.length Boolean.typ)
          ~there:(v_to_list V.length) ~back:v_of_list

      let var_to_bits = Fn.id

      let var_to_triples (bs : var) =
        Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_ bs

      let var_of_value v =
        List.init V.length ~f:(fun i -> Boolean.var_of_value (V.get v i))
    end

    let unpack_var x = Impl.Field.Checked.unpack x ~length:bit_length

    let unpack_value (x : Packed.value) : Unpacked.value = x

    let compare_var x y =
      Impl.Field.Checked.compare ~bit_length:V.length (pack_var x) (pack_var y)

    let increment_if_var bs (b : Boolean.var) =
      let open Impl in
      with_label __LOC__
        (let v = Field.Checked.pack bs in
         let v' = Field.Checked.add v (b :> Field.Checked.t) in
         Field.Checked.unpack v' ~length:V.length)

    let increment_var bs =
      let open Impl in
      with_label __LOC__
        (let v = Field.Checked.pack bs in
         let v' = Field.Checked.add v (Field.Checked.constant Field.one) in
         Field.Checked.unpack v' ~length:V.length)

    let equal_var (n : Unpacked.var) (n' : Unpacked.var) =
      with_label __LOC__ (Field.Checked.equal (pack_var n) (pack_var n'))

    let assert_equal_var (n : Unpacked.var) (n' : Unpacked.var) =
      with_label __LOC__
        (Field.Checked.Assert.equal (pack_var n) (pack_var n'))

    let if_ (cond : Boolean.var) ~(then_ : Unpacked.var)
        ~(else_ : Unpacked.var) : (Unpacked.var, _) Checked.t =
      match
        List.map2 then_ else_ ~f:(fun then_ else_ ->
            Boolean.if_ cond ~then_ ~else_ )
      with
      | Ok result -> Checked.List.all result
      | Unequal_lengths ->
          failwith "Bits.if_: unpacked bit lengths were unequal"
  end

  module UInt64 (Impl : Snarky.Snark_intf.S) =
    Small_bit_vector (Impl) (Vector.UInt64)
  module UInt32 (Impl : Snarky.Snark_intf.S) =
    Small_bit_vector (Impl) (Vector.UInt32)

  module Field_backed
      (Impl : Snarky.Snark_intf.S) (M : sig
          val bit_length : int
      end) =
  struct
    open Impl
    include M

    module Packed = struct
      type var = Field.Checked.t

      type value = Field.t

      let typ = Typ.field

      let assert_equal = Field.Checked.Assert.equal
    end

    module Unpacked = struct
      type var = Boolean.var list

      type value = Field.t

      let typ : (var, value) Typ.t =
        Typ.transport
          (Typ.list ~length:bit_length Boolean.typ)
          ~there:(unpack_field Field.unpack ~bit_length)
          ~back:Field.project

      let var_to_bits = Fn.id

      let var_to_triples (bs : var) =
        Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_ bs

      let var_of_value v =
        unpack_field Field.unpack ~bit_length v
        |> List.map ~f:Boolean.var_of_value
    end

    let project_value = Fn.id

    let project_var = Field.Checked.project

    let choose_preimage_var : Packed.var -> (Unpacked.var, _) Checked.t =
      Field.Checked.choose_preimage_var ~length:bit_length

    let unpack_value = Fn.id
  end

  module Field (Impl : Snarky.Snark_intf.S) :
    Bits_intf.Snarkable.Lossy
    with type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
     and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
     and type boolean_var := Impl.Boolean.var
     and type Packed.var = Impl.Field.Checked.t
     and type Packed.value = Impl.Field.t
     and type Unpacked.var = Impl.Boolean.var list
     and type Unpacked.value = Impl.Field.t =
    Field_backed
      (Impl)
      (struct
        let bit_length = Impl.Field.size_in_bits
      end)

  module Small
      (Impl : Snarky.Snark_intf.S) (M : sig
          val bit_length : int
      end) :
    Bits_intf.Snarkable.Faithful
    with type ('a, 'b) typ := ('a, 'b) Impl.Typ.t
     and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
     and type boolean_var := Impl.Boolean.var
     and type Packed.var = Impl.Field.Checked.t
     and type Packed.value = Impl.Field.t
     and type Unpacked.var = Impl.Boolean.var list
     and type Unpacked.value = Impl.Field.t = struct
    let () = assert (M.bit_length < Impl.Field.size_in_bits)

    include Field_backed (Impl) (M)

    let pack_var bs =
      assert (List.length bs = M.bit_length) ;
      project_var bs

    let pack_value = Fn.id

    let unpack_var = Impl.Field.Checked.unpack ~length:M.bit_length
  end
end

module Make_unpacked
    (Impl : Snarky.Snark_intf.S) (M : sig
        val bit_length : int

        val element_length : int
    end) =
struct
  open Impl

  module T = struct
    type var = Boolean.var list

    type value = Boolean.value list
  end

  include T

  let typ : (var, value) Typ.t = Typ.list ~length:M.bit_length Boolean.typ
end
