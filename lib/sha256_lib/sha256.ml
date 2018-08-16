open Core
open Snark_params

let bits_to_string bs =
  let bits_to_char_big_endian bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
      if b then acc lor (1 lsl (7 - i)) else acc)
    |> Char.of_int_exn
  in
  List.groupi ~break:(fun i _ _ -> i mod 8 = 0) bs
  |> List.map ~f:bits_to_char_big_endian
  |> String.of_char_list

module Gadget =
  Snarky.Sha256.Make (struct
      let prefix = Tick_curve.prefix
    end)
    (Tick)
    (Tick_curve)

let pad zero bits =
  let n = List.length bits in
  assert (n <= Gadget.Block.length_in_bits);
  let padding_length = Gadget.Block.length_in_bits - n in
  bits @ List.init padding_length ~f:(fun _ -> zero)

let words_to_bits ws =
  let word_size = 32 in
  let rec go i acc =
    if i < 0
    then acc
    else
      let w = ws.(i) in
      go (i - 1)
        (List.rev_append
          (List.init word_size ~f:(fun j -> 
             Int32.((w lsr j) land one = one)))
          acc)
  in
  go (Array.length ws - 1) []

let digest bits =
  Digestif.SHA256.(
    feed_string (init ())
      (bits_to_string (pad false bits))).h
  |> words_to_bits

module Checked = struct
  open Tick
  open Let_syntax

  let digest bits =
    let open Gadget in
    State.Checked.update
      State.Checked.default_init
      (Block.of_list_exn (pad Boolean.false_ bits))
    >>| State.Checked.digest
end

let%test_unit "sha-checked-and-unchecked" =
  let bitstring bs = List.map bs ~f:(fun b -> if b then '1' else '0') |> String.of_char_list in
  let gen =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind length = Int.gen_incl 0 (Gadget.Block.length_in_bits - 1) in
    Quickcheck.Generator.list_with_length length Bool.gen
  in
  Quickcheck.test ~trials:30 gen ~f:(fun bits ->
    let from_gadget =
      let t =
        Tick.Checked.map (Checked.digest (List.map ~f:Tick.Boolean.var_of_value bits))
          ~f:(Tick.As_prover.read Gadget.Digest.typ)
      in
      snd (Or_error.ok_exn (Tick.run_and_check t ()))
    in
    let native = digest bits in
    if not ([%eq: bool list] from_gadget native)
    then failwithf "%s <> %s (on input %s)" (bitstring from_gadget) (bitstring native) (bitstring bits) ())

