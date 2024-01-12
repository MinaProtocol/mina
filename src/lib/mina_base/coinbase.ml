open Core_kernel
open Mina_base_import

(** See documentation of the {!Mina_wire_types} library *)
module Wire_types = Mina_wire_types.Mina_base.Coinbase

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Coinbase_intf.Full with type Stable.V1.t = A.V1.t
end

module Make_str (A : Wire_types.Concrete) = struct
  module Fee_transfer = Coinbase_fee_transfer

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = A.V1.t =
        { receiver : Public_key.Compressed.Stable.V1.t
        ; amount : Currency.Amount.Stable.V1.t
        ; fee_transfer : Fee_transfer.Stable.V1.t option
        }
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id

      let description = "Coinbase"

      let version_byte = Base58_check.Version_bytes.coinbase
    end
  end]

  module Base58_check = Codable.Make_base58_check (Stable.Latest)

  [%%define_locally
  Base58_check.(to_base58_check, of_base58_check, of_base58_check_exn)]

  let receiver_pk t = t.receiver

  let receiver t = Account_id.create t.receiver Token_id.default

  (* This must match [Transaction_union].
     TODO: enforce this.
  *)
  let fee_payer_pk cb =
    match cb.fee_transfer with None -> cb.receiver | Some ft -> ft.receiver_pk

  let amount t = t.amount

  let fee_transfer t = t.fee_transfer

  let account_access_statuses t (status : Transaction_status.t) =
    let access_status =
      match status with Applied -> `Accessed | Failed _ -> `Not_accessed
    in
    let account_ids =
      receiver t
      :: List.map ~f:Fee_transfer.receiver (Option.to_list t.fee_transfer)
    in
    List.map account_ids ~f:(fun acct_id -> (acct_id, access_status))

  let accounts_referenced t =
    List.map (account_access_statuses t Transaction_status.Applied)
      ~f:(fun (acct_id, _status) -> acct_id)

  let is_valid { amount; fee_transfer; _ } =
    match fee_transfer with
    | None ->
        true
    | Some { fee; _ } ->
        Currency.Amount.(of_fee fee <= amount)

  let create ~amount ~receiver ~fee_transfer =
    let t = { receiver; amount; fee_transfer } in
    if is_valid t then
      let adjusted_fee_transfer =
        Option.bind fee_transfer ~f:(fun fee_transfer ->
            Option.some_if
              (not
                 (Public_key.Compressed.equal receiver
                    (Fee_transfer.receiver_pk fee_transfer) ) )
              fee_transfer )
      in
      Ok { t with fee_transfer = adjusted_fee_transfer }
    else Or_error.error_string "Coinbase.create: invalid coinbase"

  let expected_supply_increase { receiver = _; amount; fee_transfer } =
    match fee_transfer with
    | None ->
        Ok amount
    | Some { fee; _ } ->
        Currency.Amount.sub amount (Currency.Amount.of_fee fee)
        |> Option.value_map
             ~f:(fun _ -> Ok amount)
             ~default:(Or_error.error_string "Coinbase underflow")

  let fee_excess t =
    Or_error.map (expected_supply_increase t) ~f:(fun _increase ->
        Fee_excess.empty )

  module Gen = struct
    let gen ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
      let open Quickcheck.Let_syntax in
      let%bind receiver = Public_key.Compressed.gen in
      let%bind supercharged_coinbase = Quickcheck.Generator.bool in
      let%bind amount =
        let max_amount = constraint_constants.coinbase_amount in
        (* amount should be at least the account creation fee to pay for the creation of coinbase receiver and the fee transfer receiver below *)
        let min_amount =
          Option.value_exn
            (Currency.Fee.scale constraint_constants.account_creation_fee 2)
          |> Currency.Amount.of_fee
        in
        let%map amount = Currency.Amount.(gen_incl min_amount max_amount) in
        if supercharged_coinbase then
          Option.value_exn
            (Currency.Amount.scale amount
               constraint_constants.supercharged_coinbase_factor )
        else amount
      in
      (* keep account-creation fee for the coinbase-receiver *)
      let max_fee =
        Option.value_exn
          (Currency.Fee.sub
             (Currency.Amount.to_fee amount)
             constraint_constants.account_creation_fee )
      in
      let min_fee = constraint_constants.account_creation_fee in
      let%map fee_transfer =
        Option.quickcheck_generator (Fee_transfer.Gen.gen ~min_fee max_fee)
      in
      let fee_transfer =
        match fee_transfer with
        | Some { Fee_transfer.receiver_pk; _ }
          when Public_key.Compressed.equal receiver receiver_pk ->
            (* Erase fee transfer, to mirror [create]. *)
            None
        | _ ->
            fee_transfer
      in
      ( { receiver; amount; fee_transfer }
      , `Supercharged_coinbase supercharged_coinbase )

    let with_random_receivers ~keys ~min_amount ~max_amount ~fee_transfer =
      let open Quickcheck.Let_syntax in
      let%bind receiver =
        let open Signature_lib in
        Quickcheck_lib.of_array keys
        >>| fun keypair -> Public_key.compress keypair.Keypair.public_key
      and amount =
        Int.gen_incl min_amount max_amount
        >>| Currency.Amount.of_nanomina_int_exn
      in
      let%map fee_transfer =
        Option.quickcheck_generator (fee_transfer ~coinbase_amount:amount)
      in
      let fee_transfer =
        match fee_transfer with
        | Some { Fee_transfer.receiver_pk; _ }
          when Public_key.Compressed.equal receiver receiver_pk ->
            (* Erase fee transfer, to mirror [create]. *)
            None
        | _ ->
            fee_transfer
      in
      { receiver; amount; fee_transfer }
  end
end

include Wire_types.Make (Make_sig) (Make_str)
