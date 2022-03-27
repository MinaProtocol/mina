module type Inputs_intf = sig
  type proof_elem

  type hash

  val equal_hash : hash -> hash -> bool

  val hash : hash -> proof_elem -> hash
end

module Make_intf : functor (Input : Inputs_intf) -> sig
  module type S = sig
    val verify :
         init:Input.hash
      -> Input.proof_elem list
      -> Input.hash
      -> Input.hash Non_empty_list.t option
  end
end

module Make : functor (Input : Inputs_intf) -> Make_intf(Input).S
