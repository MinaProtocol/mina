open Core
open Import

module Single = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Public_key.Compressed.Stable.V1.t * Currency.Fee.Stable.V1.t
      [@@deriving sexp, compare, eq, yojson, hash]

      let to_latest = Fn.id

      let description = "Fee transfer Single"

      let version_byte = Base58_check.Version_bytes.fee_transfer_single
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, compare, yojson, hash]

  include Comparable.Make (Stable.Latest)
  module Base58_check = Codable.Make_base58_check (Stable.Latest)

  [%%define_locally
  Base58_check.(to_base58_check, of_base58_check, of_base58_check_exn)]

  [%%define_locally
  Base58_check.String_ops.(to_string, of_string)]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Single.Stable.V1.t One_or_two.Stable.V1.t
    [@@deriving sexp, compare, eq, yojson, hash]

    let to_latest = Fn.id
  end
end]

type t = Single.Stable.Latest.t One_or_two.Stable.Latest.t
[@@deriving sexp, compare, yojson, hash]

include Comparable.Make (Stable.Latest)

let fee_excess = function
  | `One (_, fee) ->
      Ok (Currency.Fee.Signed.negate @@ Currency.Fee.Signed.of_unsigned fee)
  | `Two ((_, fee1), (_, fee2)) -> (
    match Currency.Fee.add fee1 fee2 with
    | None ->
        Or_error.error_string "Fee_transfer.fee_excess: overflow"
    | Some res ->
        Ok (Currency.Fee.Signed.negate @@ Currency.Fee.Signed.of_unsigned res)
    )

let receivers t = One_or_two.map t ~f:(fun (pk, _) -> pk)

let receiver_ids =
  One_or_two.map ~f:(fun (pk, _) -> Account_id.create pk Token_id.default)
