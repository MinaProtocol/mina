open Core
open Import

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { receiver: Public_key.Compressed.Stable.V1.t
      ; amount: Currency.Amount.Stable.V1.t
      ; fee_transfer: Fee_transfer.Single.Stable.V1.t option }
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { receiver: Public_key.Compressed.t
  ; amount: Currency.Amount.t
  ; fee_transfer: Fee_transfer.Single.t option }
[@@deriving sexp, compare, eq, hash, yojson]

let is_valid {amount; fee_transfer; _} =
  match fee_transfer with
  | None ->
      true
  | Some (_, fee) ->
      Currency.Amount.(of_fee fee <= amount)

let create ~amount ~receiver ~fee_transfer =
  let t = {receiver; amount; fee_transfer} in
  if is_valid t then
    let adjusted_fee_transfer =
      if
        Public_key.Compressed.equal
          (Option.value_map fee_transfer ~default:receiver ~f:fst)
          receiver
      then None
      else fee_transfer
    in
    Ok {t with fee_transfer= adjusted_fee_transfer}
  else Or_error.error_string "Coinbase.create: invalid coinbase"

let supply_increase {receiver= _; amount; fee_transfer} =
  match fee_transfer with
  | None ->
      Ok amount
  | Some (_, fee) ->
      Currency.Amount.sub amount (Currency.Amount.of_fee fee)
      |> Option.value_map
           ~f:(fun _ -> Ok amount)
           ~default:(Or_error.error_string "Coinbase underflow")

let fee_excess t =
  Or_error.map (supply_increase t) ~f:(fun _increase ->
      Currency.Fee.Signed.zero )

let gen =
  let open Quickcheck.Let_syntax in
  let%bind receiver = Public_key.Compressed.gen in
  let%bind amount =
    Currency.Amount.(gen_incl zero Coda_compile_config.coinbase)
  in
  let fee =
    Currency.Fee.gen_incl Currency.Fee.zero (Currency.Amount.to_fee amount)
  in
  let prover = Public_key.Compressed.gen in
  let%map fee_transfer =
    Option.quickcheck_generator (Quickcheck.Generator.tuple2 prover fee)
  in
  {receiver; amount; fee_transfer}
