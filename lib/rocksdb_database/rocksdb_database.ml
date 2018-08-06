type t = Rocks.t

let create ~directory =
  let opts = Rocks.Options.create () in
  Rocks.Options.set_create_if_missing opts true ;
  Rocks.open_db ~opts directory

let destroy = Rocks.close

let get t ~key = Rocks.get ?pos:None ?len:None ?opts:None t key

let set =
  Rocks.put ?key_pos:None ?key_len:None ?value_pos:None ?value_len:None
    ?opts:None

let delete = Rocks.delete ?pos:None ?len:None ?opts:None
