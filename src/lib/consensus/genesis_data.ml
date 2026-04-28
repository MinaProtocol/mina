open Core

let genesis_ledger_total_currency ~ledger =
  Mina_ledger.Ledger.foldi ~init:Currency.Amount.zero (Lazy.force ledger)
    ~f:(fun _addr sum (account : Mina_base.Account.t) ->
      (* only default token matters for total currency used to determine stake *)
      if Mina_base.(Token_id.equal account.token_id Token_id.default) then
        Currency.Amount.add sum (Currency.Balance.to_amount @@ account.balance)
        |> Base.Option.value_exn ?here:None ?error:None
             ~message:"failed to calculate total currency in genesis ledger"
      else sum )

let genesis_ledger_hash ~ledger =
  Mina_ledger.Ledger.merkle_root (Lazy.force ledger)
  |> Mina_base.Frozen_ledger_hash.of_ledger_hash

module Hashed = struct
  type t =
    { total_currency : Currency.Amount.t
    ; hash : Mina_base.Frozen_ledger_hash.t
    }

  let hash t = t.hash

  let zero_total_currency (t : t) : t =
    { hash = t.hash; total_currency = Currency.Amount.zero }
end

module Epoch = struct
  module Data = struct
    type 'ledger t = { ledger : 'ledger; seed : Mina_base.Epoch_seed.t }

    let map ~f { ledger; seed } = { ledger = f ledger; seed }

    let to_hashed (t : Genesis_ledger.Packed.t t) : Hashed.t t =
      let total_currency =
        genesis_ledger_total_currency ~ledger:(Genesis_ledger.Packed.t t.ledger)
      in
      let hash =
        genesis_ledger_hash ~ledger:(Genesis_ledger.Packed.t t.ledger)
      in
      { ledger = { hash; total_currency }; seed = t.seed }
  end

  type 'ledger tt = { staking : 'ledger Data.t; next : 'ledger Data.t option }

  type 'ledger t = 'ledger tt option

  let zero_total_currency (t : Hashed.t t) : Hashed.t t =
    Option.map
      ~f:(fun x ->
        { staking = Data.map ~f:Hashed.zero_total_currency x.staking
        ; next = Option.map ~f:(Data.map ~f:Hashed.zero_total_currency) x.next
        } )
      t

  let for_unit_tests : Genesis_ledger.Packed.t t = None

  let compiled : Genesis_ledger.Packed.t t = None

  let to_hashed (ledger : Genesis_ledger.Packed.t t) : Hashed.t t =
    Option.map
      ~f:(fun l ->
        let staking = Data.to_hashed l.staking in
        let next = Option.map ~f:Data.to_hashed l.next in
        { staking; next } )
      ledger
end

module Ledger = struct
  type t = Genesis_ledger.Packed.t

  let to_hashed (t : t) : Hashed.t =
    { hash = genesis_ledger_hash ~ledger:(Genesis_ledger.Packed.t t)
    ; total_currency =
        genesis_ledger_total_currency ~ledger:(Genesis_ledger.Packed.t t)
    }
end
