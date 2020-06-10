open Core_kernel

(** utility function to print digests to put in tests, see `check_serialization' below *)
let print_digest digest = printf "\"" ; printf "%s" digest ; printf "\"\n%!"

(** use this function to test Bin_prot serialization of types with asserted versioning *)
let check_serialization (type t) (module M : Binable.S with type t = t) (t : t)
    known_good_digest =
  (* serialize value *)
  let sz = M.bin_size_t t in
  let buf = Bin_prot.Common.create_buf sz in
  ignore (M.bin_write_t buf ~pos:0 t) ;
  let bytes = Bytes.create sz in
  ignore (Bin_prot.Common.blit_buf_bytes buf bytes ~len:sz) ;
  (* compute MD5 digest of serialization *)
  let digest = Md5.digest_bytes bytes |> Md5.to_hex in
  let result = String.equal digest known_good_digest in
  if not result then (
    printf "Expected digest: " ;
    print_digest known_good_digest ;
    printf "Got digest:      " ;
    print_digest digest ) ;
  result
