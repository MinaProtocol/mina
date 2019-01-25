open Core
open Snark_params
open Coda_digestif

let chunks_of n xs = List.groupi ~break:(fun i _ _ -> i mod n = 0) xs

let bits_to_string bs =
  let bits_to_char_big_endian bs =
    List.foldi bs ~init:0 ~f:(fun i acc b ->
        if b then acc lor (1 lsl (7 - i)) else acc )
    |> Char.of_int_exn
  in
  chunks_of 8 bs |> List.map ~f:bits_to_char_big_endian |> String.of_char_list

module Gadget =
  Snarky.Sha256.Make (struct
      let prefix = Tick_backend.prefix
    end)
    (Tick)
    (Tick_backend)

module Digest = Gadget.Digest

let pad zero bits =
  let nearest_multiple ~of_:n k =
    let r = k mod n in
    if Int.equal r 0 then k else k - r + n
  in
  let n = List.length bits in
  let padding_length =
    nearest_multiple ~of_:Gadget.Block.length_in_bits n - n
  in
  bits @ List.init padding_length ~f:(fun _ -> zero)

let words_to_bits ws =
  let word_size = 32 in
  let rec go i acc =
    if i < 0 then acc
    else
      let w = ws.(i) in
      go (i - 1)
        (List.rev_append
           (List.init word_size ~f:(fun j -> Int32.((w lsr j) land one = one)))
           acc)
  in
  go (Array.length ws - 1) []

let digest_string (s : string) : Digest.t =
  let n = String.length s in
  let block_length = Gadget.Block.length_in_bits / 8 in
  let r = n mod block_length in
  let t =
    if r = 0 then s else s ^ String.init ~f:(fun _ -> '\000') (block_length - r)
  in
  Digest.of_bits
    (Digestif.SHA256.(feed_string (init ()) t |> get_h) |> words_to_bits)

let digest_bits (bits : bool list) : Digest.t =
  Digest.of_bits
  @@ ( Digestif.SHA256.(
         feed_string (init ()) (bits_to_string (pad false bits)) |> get_h)
     |> words_to_bits )

module Checked = struct
  open Tick
  open Let_syntax

  let digest bits =
    let open Gadget in
    Checked.List.fold ~init:State.Checked.default_init
      (chunks_of 512 (pad Boolean.false_ bits))
      ~f:(fun acc xs -> State.Checked.update acc (Block.of_list_exn xs))
    >>| State.Checked.digest
end

let%test_unit "sha-checked-and-unchecked" =
  let gen =
    let open Quickcheck.Generator in
    let open Let_syntax in
    let%bind length = small_positive_int in
    Quickcheck.Generator.list_with_length length Bool.gen
  in
  Quickcheck.test ~trials:30 gen ~f:(fun bits ->
      let from_gadget =
        let t =
          Tick.Checked.map
            (Checked.digest (List.map ~f:Tick.Boolean.var_of_value bits))
            ~f:(Tick.As_prover.read Gadget.Digest.typ)
        in
        snd (Or_error.ok_exn (Tick.run_and_check t ()))
      in
      let native_string = digest_string (bits_to_string bits) in
      let native_bits = digest_bits bits in
      if not ([%eq: Digest.t] from_gadget native_string) then
        failwithf
          !"%{sexp: Digest.t} <> %{sexp: Digest.t} (on input %s)"
          from_gadget native_string (bits_to_string bits) ()
      else if not ([%eq: Digest.t] from_gadget native_bits) then
        failwithf
          !"%{sexp: Digest.t} <> %{sexp: Digest.t} (on input %s)"
          from_gadget native_bits (bits_to_string bits) () )
