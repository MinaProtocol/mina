module BlockTime = struct
  type nonrec t = Block_time.t

  let parse json = Yojson.Basic.Util.to_string json |> Block_time.of_string_exn

  let serialize timestamp = `String (Block_time.to_string timestamp)

  let typ () = Graphql_async.Schema.scalar "BlockTime" ~coerce:serialize
end
