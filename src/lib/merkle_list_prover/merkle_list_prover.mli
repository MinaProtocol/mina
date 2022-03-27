module type Inputs_intf = sig
  type value

  type proof_elem

  type context

  module M : Core_kernel.Monad.S

  val to_proof_elem : value -> proof_elem

  val get_previous : context:context -> value -> value option M.t
end

module Make_intf : functor
  (M : Core_kernel.Monad.S)
  (Input : sig
     type value

     type proof_elem

     type context

     val to_proof_elem : value -> proof_elem

     val get_previous : context:context -> value -> value option M.t
   end)
  -> sig
  module type S = sig
    val prove :
         ?length:int
      -> context:Input.context
      -> Input.value
      -> (Input.value * Input.proof_elem list) M.t
  end
end

module Make : functor
  (M : Core_kernel.Monad.S)
  (Input : sig
     type value

     type proof_elem

     type context

     val to_proof_elem : value -> proof_elem

     val get_previous : context:context -> value -> value option M.t
   end)
  -> Make_intf(M)(Input).S

module Make_ident : functor
  (Input : sig
     type value

     type proof_elem

     type context

     val to_proof_elem : value -> proof_elem

     val get_previous :
       context:context -> value -> value option Core_kernel.Monad.Ident.t
   end)
  -> sig
  val prove :
       ?length:int
    -> context:Input.context
    -> Input.value
    -> (Input.value * Input.proof_elem list) Core_kernel.Monad.Ident.t
end
