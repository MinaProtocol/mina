module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let transaction_status () =
  enum "TransactionStatus" ~doc:"Status of a transaction"
    ~values:
    Transaction_inclusion_status.State.
  [ enum_value "INCLUDED" ~value:Included
      ~doc:"A transaction that is on the longest chain"
  ; enum_value "PENDING" ~value:Pending
      ~doc:
      "A transaction either in the transition frontier or in \
       transaction pool but is not on the longest chain"
  ; enum_value "UNKNOWN" ~value:Unknown
      ~doc:
      "The transaction has either been snarked, reached finality \
       through consensus or has been dropped"
  ]
