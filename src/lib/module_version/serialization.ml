open Core_kernel

(** utility function to print hashes to put in tests, see `check_serialization' below *)
let print_hash hash =
  printf "\"" ;
  String.iter hash ~f:(fun c -> printf "\\x%02X" (Char.to_int c)) ;
  printf "\"\n%!"

(** use this function to test Bin_prot serialization of types with asserted versioning *)

let check_serialization (type t) (module M : Binable.S with type t = t) (t : t)
    known_good_hash =
  let open Digestif.SHA256 in
  (* serialize value *)
  let sz = M.bin_size_t t in
  let buf = Bin_prot.Common.create_buf sz in
  ignore (M.bin_write_t buf ~pos:0 t) ;
  let bytes = Bytes.create sz in
  ignore (Bin_prot.Common.blit_buf_bytes buf bytes ~len:sz) ;
  let s = Bytes.to_string bytes in
  (* compute SHA256 hash of serialization *)
  let ctx0 = init () in
  let ctx1 = feed_string ctx0 s in
  let hash = get ctx1 |> to_raw_string in
  let result = String.equal hash known_good_hash in
  if not result then (
    printf "Expected hash: " ;
    print_hash known_good_hash ;
    printf "Got hash:      " ;
    print_hash hash ) ;
  result
