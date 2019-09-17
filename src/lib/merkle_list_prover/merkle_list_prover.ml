open Core_kernel

module type Inputs_intf = sig
  type value

  type proof_elem

  type context

  val to_proof_elem : value -> proof_elem

  val get_previous : context:context -> value -> value option
end

module Make_intf (Input : Inputs_intf) = struct
  module type S = sig
    val prove :
         context:Input.context
      -> Input.value
      -> Input.value * Input.proof_elem list
  end
end

module Make (Input : Inputs_intf) : Make_intf(Input).S = struct
  open Input

  let prove ~context last =
    let rec find_path value =
      Option.value_map (get_previous ~context value) ~default:(value, [])
        ~f:(fun parent ->
          let first, proofs = find_path parent in
          (first, to_proof_elem value :: proofs) )
    in
    let first, proofs = find_path last in
    (first, List.rev proofs)
end
