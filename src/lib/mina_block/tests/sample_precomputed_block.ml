(* DO NOT CHANGE THIS
   This is used to check the serialization of precomputed blocks, which must
   remain stable.

   IMPORTANT: THESE SERIALIZATIONS HAVE CHANGED SINCE THE FORMAT USED AT MAINNET LAUNCH
*)

(** Load the sample block from an external file.

    This improves code readability by moving the large sexp and json data
    structure to a separate file while maintaining the same functionality. *)
let load_sample_block filename =
  In_channel.with_open_text filename (fun ic ->
      In_channel.input_all ic |> String.trim )

let sample_block_sexp = load_sample_block "sample_precomputed_block.sexp"

let sample_block_json = load_sample_block "sample_precomputed_block.json"
