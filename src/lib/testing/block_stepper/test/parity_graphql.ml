(* Typed GraphQL query definitions for parity_test.ml.

   Isolated in a separate file so [@@@coverage exclude_file] applies only to
   the graphql_ppx-generated code and not to the rest of the test. *)

[@@@coverage exclude_file]

(* graphql_ppx uses Stdlib symbols instead of Base *)
open Stdlib
module Encoders = Mina_graphql.Types.Input
module Scalars = Graphql_lib.Scalars

module Genesis_block =
[%graphql
{|
  query {
    genesisBlock {
      stateHash @ppxCustom(module: "Graphql_lib.Scalars.String_json")
    }
  }
|}]

module Send_payment =
[%graphql
{|
  mutation ($input: SendPaymentInput!) @encoders(module: "Encoders") {
    sendPayment(input: $input) {
      payment { hash }
    }
  }
|}]
