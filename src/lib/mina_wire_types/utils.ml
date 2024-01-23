(** Signature maker provided by implentation module *)
module type Signature = functor
  (_ : sig
     type t
   end)
  -> sig
  module type S
end
