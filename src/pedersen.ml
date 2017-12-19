open Core_kernel

module Digest = struct
  type t = string [@@deriving bin_io]
end
