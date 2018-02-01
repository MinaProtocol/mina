open Core_kernel
open Util

(* Someday: Make more efficient by giving Field.unpack a length argument in
camlsnark *)
let unpack_field unpack ~bit_length x =
  List.take (unpack x) bit_length 

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

  module Int64 : S with type t = Int64.t = struct
    include Int64

    let length = 64
    let get t i = Int64.((t lsr i) land one = one)

    let empty = Int64.zero

    let get t i = (t lsr i) land one = one
    let set t i b =
      if b
      then t lor (one lsl i)
      else t land (lnot (one lsl i))
  end

  module Make (V : Basic)
    : Bits_intf.S with type t := V.t =
  struct
    let fold t ~init ~f =
      let rec go acc i =
        if i = V.length
        then acc
        else go (f acc (V.get t i)) (i + 1)
      in
      go init 0

    let iter t ~f =
      for i = 0 to V.length - 1 do
        f (V.get t i)
      done

    let to_bits t = List.init V.length ~f:(V.get t)
  end

  module Bigstring (M : sig val bit_length : int end)
    : Basic with type t = Bigstring.t
  = struct
    type t = Bigstring.t

    let char_nth_bit c n = ((Char.to_int c lsl n) land 1) = 1

    let get t n =
      char_nth_bit (Bigstring.get t (n / bits_per_char))
        (n mod bits_per_char)

    let length = M.bit_length
  end
end

module Int64 : Bits_intf.S with type t := Int64.t = Vector.Make(Vector.Int64)

module Make_field0
    (Field : Camlsnark.Field_intf.S)
    (Bigint : Camlsnark.Bigint_intf.S with type field := Field.t)
    (M : sig val bit_length : int end)
  : Bits_intf.S with type t = Field.t
=
struct
  open M

  type t = Field.t

  let fold t ~init ~f =
    let n = Bigint.of_field t in
    let rec go acc i =
      if i = bit_length
      then acc
      else
        go (f acc (Bigint.test_bit n i)) (i + 1)
    in
    go init 0
  ;;

  let iter t ~f =
    let n = Bigint.of_field t in
    for i = 0 to bit_length - 1 do
      f (Bigint.test_bit n i)
    done
  ;;

  let to_bits t =
    let n = Bigint.of_field t in
    let rec go acc i =
      if i < 0
      then acc
      else go (Bigint.test_bit n i :: acc) (i - 1)
    in
    go [] (bit_length - 1)
  ;;
end

module Make_field
    (Field : Camlsnark.Field_intf.S)
    (Bigint : Camlsnark.Bigint_intf.S with type field := Field.t)
  : Bits_intf.S with type t = Field.t
= Make_field0(Field)(Bigint)(struct let bit_length = Field.size_in_bits end)

module Snarkable = struct
  module Small_bit_vector
    (Impl : Camlsnark.Snark_intf.S)
    (V : sig
       type t
       val empty : t
       val length : int
       val get : t -> int -> bool
       val set : t -> int -> bool -> t
     end)
    : Bits_intf.Snarkable
       with type ('a, 'b) var_spec := ('a, 'b) Impl.Var_spec.t
        and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
        and type boolean_var := Impl.Boolean.var
        and type Packed.var = Impl.Cvar.t
        and type Packed.value = V.t
    =
  struct
    open Impl

    let bit_length = V.length

    let () = assert (bit_length < Field.size_in_bits)

    let init ~f =
      let rec go acc i =
        if i = V.length
        then acc
        else go (V.set acc i (f i)) (i + 1)
      in
      go V.empty 0

    module Packed = struct
      type var = Cvar.t
      type value = V.t

      let spec : (var, value) Var_spec.t =
        let open Var_spec in
        let read v =
          let open Read.Let_syntax in
          let%map x = Read.read v in
          let n = Bigint.of_field x in
          init ~f:(fun i -> Bigint.test_bit n i)
        in
        let store t =
          let open Store.Let_syntax in
          let rec go two_to_the_i i acc =
            if i = V.length
            then acc
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
        { read; store; alloc; check }
    end

    type var = (Packed.var, Boolean.var list) Dual.t

    let v_to_list n v =
      List.init n ~f:(fun i -> if i < V.length then V.get v i else false)

    let v_of_list vs =
      List.foldi vs ~init:V.empty
        ~f:(fun i acc b -> if i < V.length then V.set acc i b else acc)

    module Unpacked = struct
      include Vector.Make(V)

      type var = Boolean.var list
      type value = V.t

      let spec : (var, value) Var_spec.t =
        Var_spec.transport (Var_spec.list ~length:V.length Boolean.spec)
          ~there:(v_to_list V.length)
          ~back:v_of_list
    end

    module Checked = struct
      let to_bits = Fn.id

      let padding =
        List.init (Field.size_in_bits - bit_length)
          ~f:(fun _ -> Boolean.false_)

      let pad x = x @ padding

      let unpack x = Checked.unpack x ~length:bit_length
    end

    let unpack (x : Packed.value) : Unpacked.value = x
  end

  module Int64 (Impl : Camlsnark.Snark_intf.S) =
    Small_bit_vector(Impl)(Vector.Int64)

  module Bitstring
      (Impl : Camlsnark.Snark_intf.S)
      (M : sig val bit_length : int end)
    : Bits_intf.Snarkable
       with type ('a, 'b) var_spec := ('a, 'b) Impl.Var_spec.t
        and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
        and type boolean_var := Impl.Boolean.var
        and type Packed.var = Impl.Cvar.t list
        and type Packed.value = Bigstring.t
        and type Unpacked.var = Impl.Boolean.var list
        and type Unpacked.value = Bigstring.t
    =
  struct
    open Impl

    include M

    let bits_per_element = Field.size_in_bits - 1

    let int_nth_bit c n = ((c lsr n) land 1) = 1

    let chunks_of n xs =
      List.groupi xs ~break:(fun i _ _ -> i mod n = 0)

    let of_bool_list bs =
      let n = Float.(to_int (round_up (of_int (List.length bs) /. 8.))) in
      let t = Bigstring.create n in
      let bits_to_char bs =
        List.foldi bs ~init:0 ~f:(fun i acc b ->
          if b then acc + (1 lsl i) else acc)
        |> Char.of_int_exn
      in
      List.iteri (chunks_of bits_per_char bs) ~f:(fun i b ->
        Bigstring.set t i (bits_to_char b));
      t
    ;;

    let element_length =
      Float.to_int
        (Float.round_up (Float.of_int bit_length /. Float.of_int bits_per_element))

    module V = Vector.Bigstring(M)
    module Bits = Vector.Make(V)

    module Unpacked = struct
      include Bits

      type var = Boolean.var list
      type value = Bigstring.t

      let spec : (var, value) Var_spec.t =
        let open Var_spec in
        let store (t : value) : var Store.t =
          let open Store.Let_syntax in
          let rec go acc i =
            if i < 0
            then return acc
            else
              let b = V.get t i in
              let%bind b = Boolean.spec.store b in
              go (b :: acc) (i - 1)
          in
          go [] (bits_per_char * Bigstring.length t)
        in
        let read bs =
          Read.map (Read.all (List.map ~f:Boolean.spec.read bs))
            ~f:of_bool_list
        in
        let check bs = Checked.all_ignore (List.map ~f:Boolean.spec.check bs) in
        let alloc = Alloc.all (List.init bit_length ~f:(fun _ -> Boolean.spec.alloc)) in
        { store; read; check; alloc }
      ;;
    end

    let bits_in_final_elt = bit_length mod bits_per_element

    module Packed = struct
      type var = Cvar.t list
      type value = Bigstring.t

      let char_to_field c =
        let n = Char.to_int c in
        let rec go two_to_the_i acc i =
          if i = bits_per_char
          then acc
          else
            let acc =
              if int_nth_bit n i
              then Field.add acc two_to_the_i
              else acc
            in
            go (Field.add two_to_the_i two_to_the_i) acc (i + 1)
        in
        go Field.one Field.zero 0
      ;;

      let bits_to_field bs =
        let rec go acc pt = function
          | [] -> acc
          | b :: bs ->
            go (if b then Field.add acc pt else acc) (Field.add pt pt) bs
        in
        go Field.zero Field.one bs
      ;;

      let spec =
        let open Var_spec in
        (* someday: make efficient *)
        let store t =
          Bits.to_bits t
          |> chunks_of bits_per_element
          |> List.map ~f:(fun bs -> field.store (bits_to_field bs))
          |> Store.all
        in
        let read vs = failwith "TODO" in
        let alloc = Alloc.all (List.init element_length ~f:(fun _ -> field.alloc)) in
        let check _ = Checked.return () in
        { store; read; alloc; check }
      ;;

      (* Someday: make efficient by unrolling the iteration over bytes *)
      let fold (t : value) ~init ~f =
        let rec go acc i =
          if i = bit_length
          then acc
          else go (f acc (V.get t i)) (i + 1)
        in
        go init 0
      ;;

      let iter (t : value) ~f =
        for i = 0 to bit_length - 1 do
          f (V.get t i)
        done
      ;;
    end

    module Checked = struct
      let to_bits = Fn.id

      let padding =
        List.init (element_length * Field.size_in_bits - bit_length) ~f:(fun _ -> Boolean.false_)

      let pad x = x @ padding

      let unpack vs0 =
        let vs, v = split_last_exn vs0 in
        let open Let_syntax in
        let%map bss =
          Checked.all (List.map vs ~f:(Checked.unpack ~length:bits_per_element))
        and bs = Checked.unpack ~length:bits_in_final_elt v
        in
        List.concat bss @ bs
      ;;
    end

    let unpack : Packed.value -> Unpacked.value = Fn.id
  end

  module Field_backed
      (Impl : Camlsnark.Snark_intf.S)
      (M : sig val bit_length : int end)
    : Bits_intf.Snarkable
       with type ('a, 'b) var_spec := ('a, 'b) Impl.Var_spec.t
        and type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
        and type boolean_var := Impl.Boolean.var
        and type Packed.var = Impl.Cvar.t
        and type Packed.value = Impl.Field.t
        and type Unpacked.var = Impl.Boolean.var list
        and type Unpacked.value = Impl.Field.t
  = struct
    open Impl
    include M

    module Bits = Make_field0(Impl.Field)(Impl.Bigint)(M)

    module Packed = struct
      type var = Cvar.t
      type value = Field.t

      let spec = Var_spec.field

      let assert_equal = assert_equal
    end

    module Unpacked = struct
      include Bits

      type var = Boolean.var list
      type value = Field.t

      let spec : (var, value) Var_spec.t =
        Var_spec.transport (Var_spec.list ~length:bit_length Boolean.spec)
          ~there:(unpack_field Field.unpack ~bit_length)
          ~back:Field.pack
      ;;
    end

    module Checked = struct
      let unpack : Packed.var -> (Unpacked.var, _) Checked.t =
        Checked.unpack ~length:bit_length

      let padding =
        List.init (Field.size_in_bits - bit_length) ~f:(fun _ -> Boolean.false_)

      let pad x = x @ padding

      let to_bits = Fn.id
    end

    let unpack : Packed.value -> Unpacked.value = Fn.id
  end

  module Field (Impl : Camlsnark.Snark_intf.S) =
    Field_backed(Impl)(struct let bit_length = Impl.Field.size_in_bits end)

  module Small
      (Impl : Camlsnark.Snark_intf.S)
      (M : sig val bit_length : int end) = struct
    let () = assert (M.bit_length < Impl.Field.size_in_bits)

    include Field_backed(Impl)(M)
  end
end

module Make_unpacked
    (Impl : Camlsnark.Snark_intf.S)
    (M : sig val bit_length : int val element_length : int end)
= struct
  open Impl

  module T = struct
    type var = Boolean.var list
    type value = Boolean.value list
  end

  include T
  let spec : (var, value) Var_spec.t =
    Var_spec.list ~length:M.bit_length Boolean.spec

  module Padded = struct
    include T

    let spec : (var, value) Var_spec.t =
      Var_spec.list ~length:(M.element_length * Field.size_in_bits)
        Boolean.spec
  end
end
