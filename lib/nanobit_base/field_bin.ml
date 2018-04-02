open Core_kernel

module Make
    (Field : Snarky.Field_intf.S)
    (Bigint : Snarky.Bigint_intf.Extended with type field := Field.t)
= struct
  (* TODO: Figure out what the right thing to do is for conversion failures *)

  let (/^) x y = Float.(to_int (round_up (x // y)))

  let size_in_bytes = Field.size_in_bits /^ 8

  (* Someday: There should be a more efficient way of doing
    this since bigints are backed by a char[] *)
  let to_bigstring x =
    let n = Bigint.of_field x in
    let b i j =
      if Bigint.test_bit n (8 * i + j)
      then 1 lsl j
      else 0
    in
    Bigstring.init size_in_bytes ~f:(fun i ->
      Char.of_int_exn (
        let i = size_in_bytes - 1 - i in
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
  let of_bigstring s =
    Bigstring.to_string ~len:size_in_bytes ~pos:0 s
    |> Bigint.of_numeral ~base:256
    |> Bigint.to_field

  let ({ Bin_prot.Type_class.
          reader = bin_reader_t
        ; writer = bin_writer_t
        ; shape = bin_shape_t
        } as bin_t)
    =
    Bin_prot.Type_class.cnv Fn.id to_bigstring of_bigstring
      Bigstring.bin_t

  let { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ } = bin_reader_t
  let { Bin_prot.Type_class.write = bin_write_t; size = bin_size_t } = bin_writer_t

  let%test_unit "field_bigstring_self_inverse" =
    let assert_str b s =
      if b then failwith s else ()
    in
    let rec go i =
      if i = 0 then
        ()
      else
        let x = Field.random () in
        assert_str (x = of_bigstring (to_bigstring x)) (Printf.sprintf "Failed on iteration %d" i);
        go (i - 1)
    in
    go 1000
end
