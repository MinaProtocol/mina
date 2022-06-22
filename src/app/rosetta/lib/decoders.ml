module Token_s = struct
  type t = [ `Token_id of string ]

  let parse json = `Token_id (Yojson.Basic.Util.to_string json)

  let serialize (_ : t) =
    failwith "JSON serializer not implemented for Token_s"
end
