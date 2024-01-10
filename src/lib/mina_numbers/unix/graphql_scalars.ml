open Graphql_basic_scalars

module GlobalSlot =
  Make_scalar_using_to_string
    (Mina_numbers.Global_slot)
    (struct
      let name = "Globalslot"

      let doc = "globalslot"
    end)

module AccountNonce =
  Make_scalar_using_to_string
    (Mina_numbers.Account_nonce)
    (struct
      let name = "AccountNonce"

      let doc = "account nonce"
    end)

module Length =
  Make_scalar_using_to_string
    (Mina_numbers.Length)
    (struct
      let name = "Length"

      let doc = "length"
    end)
