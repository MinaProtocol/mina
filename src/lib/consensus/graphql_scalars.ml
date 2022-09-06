open Graphql_basic_scalars

module Slot =
  Make_scalar_using_to_string
    (Slot)
    (struct
      let name = "Slot"

      let doc = "slot"
    end)

module Epoch =
  Make_scalar_using_to_string
    (Epoch)
    (struct
      let name = "Epoch"

      let doc = "epoch"
    end)

module VrfScalar =
  Make_scalar_using_to_string
    (Consensus_vrf.Scalar)
    (struct
      let name = "VrfScalar"

      let doc = "consensus vrf scalar"
    end)

module VrfOutputTruncated =
  Make_scalar_using_base58_check
    (Consensus_vrf.Output.Truncated)
    (struct
      let name = "VrfOutputTruncated"

      let doc = "truncated vrf output"
    end)
