open Core_kernel

module type Inputs_intf = sig
  type value

  type proof_elem

  type context

  type hash [@@deriving eq]

  val to_proof_elem : value -> proof_elem

  val get_previous : context:context -> value -> value option

  val hash : hash -> proof_elem -> hash
end

module type S = sig
  type value

  type context

  type proof_elem

  type hash

  val prove : context:context -> value -> proof_elem list

  val verify : init:hash -> proof_elem list -> hash -> bool
end

module Make (Input : Inputs_intf) :
  S
  with type value := Input.value
   and type context := Input.context
   and type hash := Input.hash
   and type proof_elem := Input.proof_elem = struct
  open Input

  let prove ~context last =
    let rec find_path value =
      Option.value_map (get_previous ~context value) ~default:[]
        ~f:(fun parent -> to_proof_elem value :: find_path parent )
    in
    List.rev (find_path last)

  let verify ~init (merkle_list : proof_elem list) underlying_hash =
    let result_hash = List.fold merkle_list ~init ~f:hash in
    equal_hash underlying_hash result_hash
end
