open Core_kernel

type addr = Public_key.Compressed.t [@@deriving bin_io]

module Payload = struct
  module Unsigned = struct
    type t =
      { sender : addr
      ; receiver : addr
      ; amount : Int64.t
      ; fee : Int32.t
      }
    [@@deriving bin_io]
  end
  include Signature.Make(Unsigned)
end

module Unsigned = struct
  type t =
    { payload: Payload.t
    ; notary : addr
    }
  [@@deriving bin_io]
end
include Signature.Make(Unsigned)

let create ~sender ~receiver ~fee ~amount ~notary =
  sign
    { payload = Payload.sign { sender; receiver; amount; fee }
    ; notary
    }

