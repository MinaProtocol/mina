open Core
open Import

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        { producer: Public_key.Compressed.Stable.V1.t
        ; amount: Currency.Amount.Stable.V1.t
        ; fee_transfer: Fee_transfer.Single.Stable.V1.t option
        ; state_body_hash: State_body_hash.Stable.V1.t }
      [@@deriving sexp, bin_io, compare, eq, version, hash, yojson]
    end

    include T
    module Registered = Module_version.Registration.Make_latest_version (T)
    include Registered

    let is_valid {producer= _; amount; fee_transfer; state_body_hash= _} =
      match fee_transfer with
      | None ->
          true
      | Some (_, fee) ->
          Currency.Amount.(of_fee fee <= amount)

    (* check validity when deserializing *)
    include Binable.Of_binable (struct
                (* use shadowed bin_io functions *)
                type nonrec t = t

                include Registered
              end)
              (struct
                type nonrec t = t

                let to_binable t = t

                let of_binable t =
                  (* TODO: maliciously invalid data will halt the node
                     should this be just logged?
                     See issue #1767.
                  *)
                  assert (is_valid t) ;
                  t
              end)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "coda_base_coinbase"

    type latest = Latest.t
  end

  module Registrar = Module_version.Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* DO NOT add bin_io to the deriving list *)
type t = Stable.Latest.t =
  { producer: Public_key.Compressed.Stable.V1.t
  ; amount: Currency.Amount.Stable.V1.t
  ; fee_transfer: Fee_transfer.Single.Stable.V1.t option
  ; state_body_hash: State_body_hash.Stable.V1.t }
[@@deriving sexp, compare, eq, hash, yojson]

let is_valid = Stable.Latest.is_valid

let create ~amount ~producer ~fee_transfer ~state_body_hash =
  let t = {producer; amount; fee_transfer; state_body_hash} in
  if is_valid t then
    let adjusted_fee_transfer =
      if
        Public_key.Compressed.equal
          (Option.value_map fee_transfer ~default:producer ~f:fst)
          producer
      then None
      else fee_transfer
    in
    Ok {t with fee_transfer= adjusted_fee_transfer}
  else Or_error.error_string "Coinbase.create: fee transfer was too high"

let supply_increase {producer= _; amount; fee_transfer; state_body_hash= _} =
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
  let%bind producer = Public_key.Compressed.gen in
  let%bind amount =
    Currency.Amount.(gen_incl zero Coda_compile_config.coinbase)
  in
  let fee =
    Currency.Fee.gen_incl Currency.Fee.zero (Currency.Amount.to_fee amount)
  in
  let prover = Public_key.Compressed.gen in
  let%bind fee_transfer =
    Option.quickcheck_generator (Quickcheck.Generator.tuple2 prover fee)
  in
  let%map state_body_hash = State_body_hash.gen in
  {producer; amount; fee_transfer; state_body_hash}
