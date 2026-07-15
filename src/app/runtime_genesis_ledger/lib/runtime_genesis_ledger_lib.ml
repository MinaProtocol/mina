open Mina_base

let convert_account ~hardfork_slot (account : Account.t) : Account.t =
  match hardfork_slot with
  | None ->
      account
  | Some hardfork_slot ->
      Account.slot_reduction_update ~hardfork_slot account

let%test_module "vesting conversion" =
  ( module struct
    let hardfork_slot = Mina_numbers.Global_slot_since_genesis.of_int 10

    (* A timed account whose cliff is in the future relative to [hardfork_slot]
       ("not yet vesting"), so it is actively vesting and
       [slot_reduction_update] is guaranteed to re-base its timing (doubling the
       vesting period and pushing the cliff). Balances are irrelevant to this
       branch, so they are left at zero. *)
    let timed_account =
      { Account.empty with
        timing =
          Account.Timing.Timed
            { initial_minimum_balance = Currency.Balance.zero
            ; cliff_time = Mina_numbers.Global_slot_since_genesis.of_int 100
            ; cliff_amount = Currency.Amount.zero
            ; vesting_period = Mina_numbers.Global_slot_span.of_int 10
            ; vesting_increment = Currency.Amount.zero
            }
      }

    let berkeley = Account.slot_reduction_update ~hardfork_slot timed_account

    (* Guards the rest of the suite: the Berkeley -> Mesa re-base must actually
       change this account, otherwise the identity-vs-berkeley assertions below
       would pass vacuously. *)
    let%test "slot_reduction_update is non-trivial on a vesting account" =
      not (Account.equal timed_account berkeley)

    (* Berkeley -> Mesa: applies the slot-reduction re-base. *)
    let%test "conversion with Some hardfork_slot re-bases the account" =
      Account.equal berkeley
        (convert_account ~hardfork_slot:(Some hardfork_slot) timed_account)

    (* Without a hardfork slot, accounts are loaded verbatim. *)
    let%test "no hardfork slot is identity" =
      Account.equal timed_account
        (convert_account ~hardfork_slot:None timed_account)
  end )
