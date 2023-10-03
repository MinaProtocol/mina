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
