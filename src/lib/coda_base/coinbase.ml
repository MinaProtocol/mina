open Core
open Import

module T = struct
  type t =
    { proposer: Public_key.Compressed.t
    ; amount: Currency.Amount.t
    ; fee_transfer: Fee_transfer.single option }
  [@@deriving sexp, bin_io, compare, eq]
end

include T

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
      |> Option.value_map ~f:Or_error.return
           ~default:(Or_error.error_string "Coinbase underflow")

let fee_excess t =
  Or_error.map (supply_increase t) ~f:(fun _increase ->
      Currency.Fee.Signed.zero )
