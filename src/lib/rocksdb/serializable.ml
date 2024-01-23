open Core_kernel

module Make (Key : Binable.S) (Value : Binable.S) :
  Key_value_database.Intf.S
    with module M := Key_value_database.Monad.Ident
     and type key := Key.t
     and type value := Value.t
     and type config := string = struct
  type t = Database.t

  let create directory = Database.create directory

  let close = Database.close

  let get t ~key =
    let open Option.Let_syntax in
    let%map serialized_value =
      Database.get t ~key:(Binable.to_bigstring (module Key) key)
    in
    Binable.of_bigstring (module Value) serialized_value

  let get_batch t ~keys =
    Database.get_batch t
      ~keys:(List.map keys ~f:(Binable.to_bigstring (module Key)))
    |> List.map ~f:(Option.map ~f:(Binable.of_bigstring (module Value)))

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

(** Database Interface for storing heterogeneous key-value pairs. Similar to
    Janestreet's Core.Univ_map *)
module GADT = struct
  module type Database_intf = sig
    type t

    type 'a g

    val set : t -> key:'a g -> data:'a -> unit

    val set_raw : t -> key:'a g -> data:Bigstring.t -> unit

    val remove : t -> key:'a g -> unit
  end

  module type S = sig
    include Database_intf

    module T : sig
      type nonrec t = t
    end

    val create : string -> t

    val close : t -> unit

    val get : t -> key:'a g -> 'a option

    val get_raw : t -> key:'a g -> Bigstring.t option

    module Batch : sig
      include Database_intf with type 'a g := 'a g

      val with_batch : T.t -> f:(t -> 'a) -> 'a
    end
  end

  module type Key_intf = sig
    type 'a t

    val to_string : 'a t -> string

    val binable_key_type : 'a t -> 'a t Bin_prot.Type_class.t

    val binable_data_type : 'a t -> 'a Bin_prot.Type_class.t
  end

  module Make (Key : Key_intf) : S with type 'a g := 'a Key.t = struct
    let bin_key_dump (key : 'a Key.t) =
      Bin_prot.Utils.bin_dump (Key.binable_key_type key).writer key

    let bin_data_dump (key : 'a Key.t) (data : 'a) =
      Bin_prot.Utils.bin_dump (Key.binable_data_type key).writer data

    module Make_Serializer (Database : sig
      type t

      val set : t -> key:Bigstring.t -> data:Bigstring.t -> unit

      val remove : t -> key:Bigstring.t -> unit
    end) =
    struct
      type t = Database.t

      let set_raw t ~(key : 'a Key.t) ~(data : Bigstring.t) : unit =
        Database.set t ~key:(bin_key_dump key) ~data

      let set t ~(key : 'a Key.t) ~(data : 'a) : unit =
        set_raw t ~key ~data:(bin_data_dump key data)

      let remove t ~(key : 'a Key.t) = Database.remove t ~key:(bin_key_dump key)
    end

    let create directory = Database.create directory

    let close = Database.close

    module T = Make_Serializer (Database)
    include T

    let get_raw t ~(key : 'a Key.t) = Database.get t ~key:(bin_key_dump key)

    let get t ~(key : 'a Key.t) =
      let open Option.Let_syntax in
      let%map serialized_value = Database.get t ~key:(bin_key_dump key) in
      let bin_key = Key.binable_data_type key in
      bin_key.reader.read serialized_value ~pos_ref:(ref 0)

    module Batch = struct
      include Make_Serializer (Database.Batch)

      let with_batch = Database.Batch.with_batch
    end
  end
end
