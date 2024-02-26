module Key = struct
  module type S = sig
    type 'a t

    val to_string : 'a t -> string

    val binable_key_type : 'a t -> 'a t Bin_prot.Type_class.t

    val binable_data_type : 'a t -> 'a Bin_prot.Type_class.t
  end

  module type Some_key_intf = sig
    type 'a unwrapped_t

    type t = Some_key : 'a unwrapped_t -> t

    type with_value = Some_key_value : 'a unwrapped_t * 'a -> with_value
  end

  module Some_key (K : sig
    type 'a t
  end) : Some_key_intf with type 'a unwrapped_t := 'a K.t = struct
    type t = Some_key : 'a K.t -> t

    type with_value = Some_key_value : 'a K.t * 'a -> with_value
  end
end

module Database = struct
  module type Database_intf = sig
    type t

    type 'a g

    val set : t -> key:'a g -> data:'a -> unit

    val set_raw : t -> key:'a g -> data:Bigstring.t -> unit

    val remove : t -> key:'a g -> unit
  end

  module type S = sig
    include Database_intf

    module Some_key : Key.Some_key_intf with type 'a unwrapped_t := 'a g

    module T : sig
      type nonrec t = t
    end

    val create : string -> t

    val close : t -> unit

    val get : t -> key:'a g -> 'a option

    val get_raw : t -> key:'a g -> Bigstring.t option

    val get_batch : t -> keys:Some_key.t list -> Some_key.with_value option list

    module Batch : sig
      include Database_intf with type 'a g := 'a g

      val with_batch : T.t -> f:(t -> 'a) -> 'a
    end
  end
end
