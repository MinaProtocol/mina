module BlockTime : Graphql_basic_scalars.Json_intf with type t = Block_time.t =
struct
  type nonrec t = Block_time.t

  let parse json = Yojson.Basic.Util.to_string json |> Block_time.of_string_exn

  let serialize timestamp = `String (Block_time.to_string_exn timestamp)

  let typ () = Graphql_async.Schema.scalar "BlockTime" ~coerce:serialize
end
