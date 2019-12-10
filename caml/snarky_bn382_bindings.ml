open Ctypes

let with_prefix = Format.sprintf "%s_%s"

let prefix = with_prefix "camlsnark_bn382"

module Full (F : Ctypes.FOREIGN) = struct
  open F

  module Fp = struct
    let prefix = with_prefix (prefix "fp")

    let size_in_bits = foreign (prefix "size_in_bits") (void @-> returning int)
  end
end
