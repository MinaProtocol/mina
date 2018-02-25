open Core_kernel

type signature = Todo [@@deriving bin_io]

module Make (B: Binable.S):
  Signature_intf.S
    with type data = B.t
= struct
  type data = B.t [@@deriving bin_io]
  type t =
    { data : data
    ; signature : signature
    }
  [@@deriving bin_io]

  let sign a = { data = a; signature = failwith "TODO" }
  let data {data;signature} = failwith "if signature_valid then Some data else None"
end

