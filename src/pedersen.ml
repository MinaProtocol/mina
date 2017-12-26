open Core_kernel

module Digest = struct
  type t = string [@@deriving bin_io]
end

module State = struct
  type t = Todo

  let create () = failwith "TODO"

  let update _ _ : unit = failwith "TODO"

  let digest _ = failwith "TODO"
end

let hash x =
  let s = State.create () in
  State.update s x;
  State.digest s
;;

let zero_hash = failwith "TODO"
