open Core_kernel

module Make (Key : Binable.S) (Value : Binable.S) :
  Key_value_database.S with type key := Key.t and type value := Value.t =
struct
  type t = Database.t

  let create ~directory = Database.create ~directory

  let close = Database.close

  let get t ~key =
    let open Option.Let_syntax in
    let%map serialized_value =
      Database.get t ~key:(Binable.to_bigstring (module Key) key)
    in
    Binable.of_bigstring (module Value) serialized_value

  let set t ~key ~data =
    Database.set t
      ~key:(Binable.to_bigstring (module Key) key)
      ~data:(Binable.to_bigstring (module Value) data)

  let remove t ~key =
    Database.remove t ~key:(Binable.to_bigstring (module Key) key)
end
