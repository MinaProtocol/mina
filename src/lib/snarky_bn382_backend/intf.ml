module type Type_with_delete = sig
  type t

  val delete : t -> unit
end
