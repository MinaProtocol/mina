module PrecomputedBlockProof :
  Graphql_basic_scalars.Json_intf with type t = Mina_block.Precomputed.Proof.t =
struct
  open Mina_block.Precomputed.Proof

  type nonrec t = t

  let parse json = Yojson.Basic.Util.to_string json |> of_bin_string

  let serialize t = `String (to_bin_string t)

  let typ () =
    Graphql_async.Schema.scalar "PrecomputedBlockProof"
      ~doc:"Base-64 encoded proof" ~coerce:serialize
end
