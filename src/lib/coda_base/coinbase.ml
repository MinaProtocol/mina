open Core
open Import

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type t =
        { proposer: Public_key.Compressed.t
        ; amount: Currency.Amount.t
        ; fee_transfer: Fee_transfer.single option }
      [@@deriving sexp, bin_io, compare, eq]
    end

    include T
    include Module_version.Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "coda_base_coinbase"

    type latest = Latest.t
  end

  module Registrar = Module_version.Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include Stable.Latest

let is_valid {proposer= _; amount; fee_transfer} =
  match fee_transfer with
  | None -> true
  | Some (_, fee) -> Currency.Amount.(of_fee fee <= amount)

include Binable.Of_binable
          (T)
          (struct
            type nonrec t = t

            let to_binable = Fn.id

            let of_binable t =
              assert (is_valid t) ;
              t
          end)

let create ~amount ~proposer ~fee_transfer =
  let t = {proposer; amount; fee_transfer} in
  if is_valid t then Ok t
  else Or_error.error_string "Coinbase.create: fee transfer was too high"

let supply_increase {proposer= _; amount; fee_transfer} =
  match fee_transfer with
  | None -> Ok amount
  | Some (_, fee) ->
      Currency.Amount.sub amount (Currency.Amount.of_fee fee)
      |> Option.value_map
           ~f:(fun _ -> Ok amount)
           ~default:(Or_error.error_string "Coinbase underflow")

let fee_excess t =
  Or_error.map (supply_increase t) ~f:(fun _increase ->
      Currency.Fee.Signed.zero )
