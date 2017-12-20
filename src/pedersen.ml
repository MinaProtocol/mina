open Core_kernel

module Digest = struct
  type t = string [@@deriving bin_io]
end

module State = struct
  type t = Todo

  let create = failwith "TODO"

  let update = failwith "TODO"

  let digest = failwith "TODO"
end
