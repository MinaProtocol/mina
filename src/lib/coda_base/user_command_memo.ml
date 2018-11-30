open Core
open Sha256_lib
include Sha256.Digest
include Hashable.Make (Sha256.Digest)

(*TODO Currently sha-ing a string. Actula data in the memo needs to be decided *)
let max_size_in_bytes = 1000

let create_exn s =
  let max_size = 1000 in
  if String.length s > max_size_in_bytes then
    failwithf !"Memo data too long. Max size = %d" max_size ()
  else Sha256.digest_string s

let dummy = create_exn ""

include Codable.Make_of_string (struct
  type nonrec t = t

  let to_string memo = to_string memo |> B64.encode

  let of_string = Fn.compose of_string B64.decode
end)
