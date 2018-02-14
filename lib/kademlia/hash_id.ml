open Core_kernel

module Bigstring14 = Bigstring_exact.Make(struct let size = 14 end)
module Bigstring18 = Bigstring_exact.Make(struct let size = 18 end)
module Bigstring2 = Bigstring_exact.Make(struct let size = 2 end)

(* TODO: Verify the bits from the hash are MORE important in our tree *)
type t =
  { nonce : Bigstring14.t
  ; hash : Bigstring18.t
  }
[@@deriving sexp, bin_io]

let hash nonce = failwith "Find a crypto library with PBKDF2 and sha256"

(* Throws if nonce is not exactly 14bytes *)
let create ~nonce = { nonce ; hash = hash nonce }

let random_nonce () =
  Bigstring.init 14 ~f:(fun idx -> Char.of_int_exn (Random.int 256))

let verify {nonce;hash=h} = Bigstring.equal (hash nonce) h

(* TODO: Unify this with the to_bits logic in nanobit snark land? *)

let to_bits_bs bs =
  List.init ((Bigstring.length bs)*8) ~f:(fun bit ->
    let byte = bit / 8 in
    let offset = bit % 8 in
    let got = (Bigstring.get_int8 bs ~pos:byte) in
    let bitted = (got lsr offset) land 1 in
    bitted = 1
  ) |> List.rev

let%test "simple_to_bits_bs" =
  (* "0xF1 0xF0" *)
  let bs = Bigstring2.init ~f:(fun idx -> Char.of_int_exn (idx lor 0xF0)) in
  let as_bits = to_bits_bs bs in
  let bits = [true;true;true;true;
              false;false;false;true;

              true;true;true;true;
              false;false;false;false]
  in
  List.equal as_bits bits ~equal:(=)

let to_bits t =
  let bs = Bin_prot.Utils.bin_dump bin_writer_t t in
  assert ((Bigstring.length bs) = 32);
  to_bits_bs bs

let of_bits_bs bits =
  let len = List.length bits in
  let bs = Bigstring.init (len/8) ~f:(fun _ -> Char.of_int_exn 0) in
  List.iter (List.zip_exn (List.init len ~f:Fn.id) (bits |> List.rev)) ~f:(fun (idx, bit) ->
    let bit_int = if bit then 1 else 0 in
    let byte = idx/8 in
    let offset = idx%8 in
    let x = Bigstring.get_int8 bs ~pos:byte in
    let x' = x lor (bit_int lsl offset) in
    Bigstring.set_uint8 bs ~pos:byte x';
  );
  bs

let%test "simple_of_bits_bs" =
  (* "0xF1 0xF0" *)
  let bs = Bigstring2.init ~f:(fun idx -> Char.of_int_exn (idx lor 0xF0)) in
  let bits = [true;true;true;true;
              false;false;false;true;

              true;true;true;true;
              false;false;false;false]
  in
  let from_bits = of_bits_bs bits in
  from_bits = bs

let of_bits bits =
  assert ((List.length bits) = 256);
  let bs = of_bits_bs bits in
  bin_read_t bs ~pos_ref:(ref 0)

let%test "round_trip_bits" =
  let t = { nonce = Bigstring.of_string "aaaaaaaaaaaaaa" ; hash = Bigstring.of_string "zzzzzzzzzzzzzzzzzz" } in
  let t' = t |> to_bits |> of_bits in
  (Bigstring.equal t.nonce t'.nonce) &&
  (Bigstring.equal t.hash t'.hash)

