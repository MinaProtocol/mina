module Make (Inputs : Inputs_intf.S) : sig
  open Inputs

  val hash :
       ?message:Field.t array
    -> a:G1.t
    -> b:G2.t
    -> c:G1.t
    -> delta_prime:G2.t
    -> G1.t
end
