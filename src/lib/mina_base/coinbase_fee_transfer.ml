open Core_kernel
open Mina_base_import

module Make_sig (T : Mina_wire_types.Mina_base.Coinbase_fee_transfer.Types.S) =
struct
  module type S = Coinbase_fee_transfer_intf.Full with type Stable.V1.t = T.V1.t
end

module Make_str (T : Mina_wire_types.Mina_base.Coinbase_fee_transfer.Concrete) :
  Make_sig(T).S = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = T.V1.t =
        { receiver_pk : Public_key.Compressed.Stable.V1.t
        ; fee : Currency.Fee.Stable.V1.t
        }
      [@@deriving sexp, compare, equal, yojson, hash]

      let to_latest = Fn.id

      let description = "Coinbase fee transfer"

      let version_byte = Base58_check.Version_bytes.fee_transfer_single
    end
  end]

  let create ~receiver_pk ~fee = { receiver_pk; fee }

  include Comparable.Make (Stable.Latest)
  module Base58_check = Codable.Make_base58_check (Stable.Latest)

  [%%define_locally
  Base58_check.(to_base58_check, of_base58_check, of_base58_check_exn)]

  let receiver_pk { receiver_pk; _ } = receiver_pk

  let receiver { receiver_pk; _ } =
    Account_id.create receiver_pk Token_id.default

  let fee { fee; _ } = fee

  let to_fee_transfer { receiver_pk; fee } =
    Fee_transfer.Single.create ~receiver_pk ~fee ~fee_token:Token_id.default

  module Gen = struct
    let gen ?(min_fee = Currency.Fee.zero) ~max_fee : t Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let%bind receiver_pk = Public_key.Compressed.gen in
      let%map fee = Currency.Fee.gen_incl min_fee max_fee in
      { receiver_pk; fee }

    let with_random_receivers ~keys ?(min_fee = Currency.Fee.zero)
        ~coinbase_amount : t Quickcheck.Generator.t =
      let open Quickcheck.Generator.Let_syntax in
      let max_fee = Currency.Amount.to_fee coinbase_amount in
      let%map receiver_pk =
        let open Signature_lib in
        Quickcheck_lib.of_array keys
        >>| fun keypair -> Public_key.compress keypair.Keypair.public_key
      and fee = Currency.Fee.gen_incl min_fee max_fee in
      { receiver_pk; fee }
  end
end

include
  Mina_wire_types.Mina_base.Coinbase_fee_transfer.Make (Make_sig) (Make_str)
