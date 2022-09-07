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

module BodyReference = struct
  open Body_reference

  type nonrec t = t

  let parse json = Yojson.Basic.Util.to_string json |> of_hex_exn

  let serialize x = `String (to_hex x)

  let typ () =
    Graphql_async.Schema.scalar "BodyReference"
      ~doc:
        "A reference to how the block header refers to the body of the block \
         as a hex-encoded string"
      ~coerce:serialize
end
