open Core
open Digestif

(* The SHA gadget takes in and outputs big endian 32-bit words *)

let chunks_of n xs = List.groupi xs ~break:(fun i _ _ -> i mod n = 0)

let string_to_bits s =
  List.init
    (8 * String.length s)
    ~f:(fun i -> (Char.to_int s.[i / 8] lsr (7 - (i mod 8))) land 1 = 1)

module Backend = Snarky.Libsnark.Bn128.Default
module Impl = Snarky.Snark0.Make (Backend)
module SHA_gadget = Snarky.Sha256.Make (Backend) (Impl) (Backend)

let gadget_string_to_bits s =
  let open Impl in
  let open SHA_gadget in
  let block =
    Block.of_list_exn (List.map ~f:Boolean.var_of_value (string_to_bits s))
  in
  let t =
    let open Let_syntax in
    let%map res =
      State.Checked.update State.Checked.default_init block
      >>| State.Checked.digest
    in
    As_prover.read Digest.typ res
  in
  let (), x = Or_error.ok_exn (run_and_check t ()) in
  x

let gadget_string_to_words s =
  let word_of_big_endian_bits bs =
    let open Int32 in
    List.foldi bs ~init:zero ~f:(fun i acc b ->
        if b then acc lor (one lsl Int.(31 - i)) else acc )
  in
  chunks_of 32 (gadget_string_to_bits s) |> List.map ~f:word_of_big_endian_bits

let () =
  Quickcheck.test ~trials:30 (String.gen_with_length 64 Char.gen) ~f:
    (fun input ->
      [%test_eq : int32 list]
        (Array.to_list
           (Digestif.SHA256.feed_string (Digestif.SHA256.init ()) input).h)
        (gadget_string_to_words input) )
