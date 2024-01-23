open Graphql_basic_scalars

module Fee =
  Make_scalar_using_to_string
    (Currency.Fee)
    (struct
      let name = "Fee"

      let doc = "fee"
    end)

module Amount =
  Make_scalar_using_to_string
    (Currency.Amount)
    (struct
      let name = "Amount"

      let doc = "amount"
    end)

module Balance =
  Make_scalar_using_to_string
    (Currency.Balance)
    (struct
      let name = "Balance"

      let doc = "balance"
    end)
