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

  let set_batch t ?(remove_keys = []) ~update_pairs =
    let key_data_pairs =
      List.map update_pairs ~f:(fun (key, data) ->
          ( Binable.to_bigstring (module Key) key
          , Binable.to_bigstring (module Value) data ) )
    in
    let remove_keys =
      List.map remove_keys ~f:(Binable.to_bigstring (module Key))
    in
    Database.set_batch t ~remove_keys ~key_data_pairs

  let remove t ~key =
    Database.remove t ~key:(Binable.to_bigstring (module Key) key)

  let to_alist t =
    List.map (Database.to_alist t) ~f:(fun (key, value) ->
        ( Binable.of_bigstring (module Key) key
        , Binable.of_bigstring (module Value) value ) )
end
