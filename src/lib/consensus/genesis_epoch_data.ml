module Data = struct
  type 'ledger t = { ledger : 'ledger; seed : Mina_base.Epoch_seed.t }
end

type 'ledger tt = { staking : 'ledger Data.t; next : 'ledger Data.t option }

type 'ledger t = 'ledger tt option

let for_unit_tests : Genesis_ledger.Packed.t t = None

let compiled : Genesis_ledger.Packed.t t = None

type field = Snark_params.Tick.field

let hashed_of_full (ledger : Genesis_ledger.Packed.t t) : field t =
  Option.map
    (fun { staking; next } ->
      let next =
        Option.map
          (fun { Data.ledger; seed } ->
            { Data.ledger =
                Genesis_ledger.Packed.t ledger
                |> Lazy.force |> Mina_ledger.Ledger.merkle_root
            ; seed
            } )
          next
      in
      let staking : field Data.t =
        { Data.ledger =
            Genesis_ledger.Packed.t staking.ledger
            |> Lazy.force |> Mina_ledger.Ledger.merkle_root
        ; seed = staking.seed
        }
      in
      { staking; next } )
    ledger
