open Core_kernel

module Make_small_bitvector
    (Impl : Camlsnark.Snark_intf.S)
    (V : sig
       type t
       val length : int 
       val get : t -> int -> bool
       val set : t -> int -> bool -> t
     end)
  =
struct
  open Impl

  let bit_length = V.length

  let () = assert (bit_length < Field.size_in_bits)

  module Packed = struct
    type var = Cvar.t
    type value = V.t
    let spec : (var, value) Var_spec.t = failwith "TODO"
  end

  module Unpacked = struct
    type var = Boolean.var list
    type value = V.t
    let spec : (var, value) Var_spec.t = failwith "TODO"

    module Padded = struct
      type var = Boolean.var list
      type value = V.t
      let spec : (var, value) Var_spec.t = failwith "TODO"
    end
  end

  module Checked = struct
    let padding =
      List.init (Field.size_in_bits - bit_length)
        ~f:(fun _ -> Boolean.false_)

    let pad x = x @ padding

    let unpack x = Checked.unpack x ~length:bit_length
  end
end

module Make_Int64 (Impl : Camlsnark.Snark_intf.S) =
  Make_small_bitvector(Impl)(struct
    let length = 64
    include Int64

    let get t i = (t lsr i) land one = one
    let set t i b = 
      if b
      then t lor (one lsl i)
      else t land (lnot (one lsl i))
  end)

module Make_bigstring
    (Impl : Camlsnark.Snark_intf.S)
    (M : sig val byte_length : int end)
  =
struct
  open Impl

  include M
  let bits_per_char = 8
  let bit_length = byte_length * bits_per_char
  let bits_per_element = Field.size_in_bits - 1

  let int_nth_bit c n = ((c lsr n) land 1) = 1

  let to_bool_list t ~length =
    let nth_bit c n = int_nth_bit (Char.to_int c) n in
    let bits_per_char = 8 in
    List.init length ~f:(fun i ->
      nth_bit (Bigstring.get t (i / bits_per_char)) (i mod bits_per_char))
  ;;

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

  module Unpacked = struct
    type var = Boolean.var list
    type value = Bigstring.t

    let spec : (var, value) Var_spec.t =
      let open Var_spec in
      let nth_bit c n = ((Char.to_int c lsl n) land 1) = 1 in
      let store (t : value) : var Store.t =
        let open Store.Let_syntax in
        let rec go acc i =
          if i < 0
          then return acc
          else
            let b = nth_bit (Bigstring.get t (i / bits_per_char)) (i mod bits_per_char) in
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

    module Padded = struct
      type var = Boolean.var list
      type value = Bigstring.t
      let spec = failwith "TODO"
    end
  end

  let bits_in_final_elt = bit_length mod bits_per_element

  let split_last =
    let rec go acc x xs =
      match xs with
      | [] -> List.rev acc, x
      | x' :: xs -> go (x :: acc) x' xs
    in
    function
    | [] -> failwith "split_last: Empty list"
    | x :: xs -> go [] x xs
  ;;

  module Packed = struct
    type var = Cvar.t list
    type value = Bigstring.t

    let char_to_field c =
      let n = Char.to_int c in
      let rec go pt acc i =
        if i = bits_per_char
        then acc
        else
          let acc =
            if int_nth_bit n i
            then Field.add acc pt
            else acc
          in
          go (Field.add pt pt) acc (i + 1)
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
        to_bool_list t ~length:(Bigstring.length t * bits_per_char)
        |> chunks_of bits_per_element
        |> List.map ~f:(fun bs -> field.store (bits_to_field bs))
        |> Store.all
      in
      let read vs = failwith "TODO" in
      let alloc = Alloc.all (List.init element_length ~f:(fun _ -> field.alloc)) in
      let check _ = Checked.return () in
      { store; read; alloc; check }
    ;;
  end

  module Checked = struct
    let padding =
      List.init (element_length * Field.size_in_bits - bit_length) ~f:(fun _ -> Boolean.false_)

    let pad x = x @ padding

    let unpack vs0 =
      let vs, v = split_last vs0 in
      let open Let_syntax in
      let%map bss =
        Checked.all (List.map vs ~f:(Checked.unpack ~length:bits_per_element))
      and bs = Checked.unpack ~length:bits_in_final_elt v
      in
      List.concat bss @ bs
    ;;
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

module Small
    (Impl : Camlsnark.Snark_intf.S)
    (M : sig val bit_length : int end) = struct
  open Impl
  include M

  let () = assert (bit_length < Field.size_in_bits)

  module Packed = struct
    type var = Cvar.t
    type value = Field.t
    let spec = Var_spec.field
  end

  module Unpacked = Make_unpacked(Impl)(struct
      include M
      let element_length = 1
    end)

  module Checked = struct
    let unpack : Packed.var -> (Unpacked.var, _) Checked.t =
      Checked.unpack ~length:bit_length

    let padding =
      List.init (Field.size_in_bits - bit_length) ~f:(fun _ -> Boolean.false_)

    let pad x = x @ padding
  end
end

module Make0
    (Impl : Camlsnark.Snark_intf.S)
    (M : sig
      val bit_length : int
(* TODO: Just make this [val kind : [`Arbitary | `Field_element]] *)
      val bits_per_element : int
    end) = struct
  open Impl

  include M

  let element_length =
    Float.(to_int (round_up (of_int bit_length / of_int bits_per_element)))

  module Packed = struct
    type var = Cvar.t list
    type value = Field.t list
    let spec = Var_spec.(list field ~length:element_length )
  end

  module Unpacked = Make_unpacked(Impl)(struct
      let bit_length = bit_length
      let element_length = element_length
    end)

  module Checked = struct
    let unpack : Packed.var -> (Unpacked.var, _) Checked.t =
      let open Let_syntax in
      let rec go remaining acc = function
        | x :: xs ->
          let to_unpack = min remaining bits_per_element in
          let%bind bs = Checked.unpack x ~length:to_unpack in
          go (remaining - to_unpack) (List.rev_append bs acc) xs
        | [] ->
          assert (remaining = 0);
          return (List.rev acc)
      in
      fun xs -> go bit_length [] xs

    let padding =
      List.init (element_length * Field.size_in_bits - bit_length)
        ~f:(fun _ -> Boolean.false_)

    let pad x = x @ padding
  end

  (* TODO: Would be nice to write this code only once. *)
  let unpack : Packed.value -> Unpacked.value =
    let rec go remaining acc = function
      | x :: xs ->
        let to_unpack = min remaining bits_per_element in
        let bs = List.take (Field.unpack x) to_unpack in
        go (remaining - to_unpack) (List.rev_append bs acc) xs
      | [] ->
        assert (remaining = 0);
        List.rev acc
    in
    fun xs -> go bit_length [] xs

  let padding =
    List.init (element_length * Field.size_in_bits - bit_length)
      ~f:(fun _ -> false)

  let pad x = x @ padding
end

module Make(Impl : Camlsnark.Snark_intf.S)(M : sig val bit_length : int end) =
  Make0(Impl)(struct
    include M
    let bits_per_element = Impl.Field.size_in_bits - 1
  end)

