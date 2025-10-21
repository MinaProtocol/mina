let json_of_option (f : 'a -> Yojson.Basic.t) (x : 'a option) : Yojson.Basic.t =
  match x with None -> `Null | Some x -> f x
