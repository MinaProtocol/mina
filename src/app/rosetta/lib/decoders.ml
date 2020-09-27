let optional ~f = function `Null -> None | json -> Some (f json)

let uint64 json = Yojson.Basic.Util.to_string json |> Unsigned.UInt64.of_string

let uint32 json = Yojson.Basic.Util.to_string json |> Unsigned.UInt32.of_string

let public_key json = Yojson.Basic.Util.to_string json

let optional_uint32 json = optional ~f:uint32 json
