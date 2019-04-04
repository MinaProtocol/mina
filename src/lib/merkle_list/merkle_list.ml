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

module Make_intf (Input : Inputs_intf) = struct
  module type S = sig
    val prove : context:Input.context -> Input.value -> Input.proof_elem list

    val verify : init:Input.hash -> Input.proof_elem list -> Input.hash -> bool
  end
end

module Make (Input : Inputs_intf) : Make_intf(Input).S = struct
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
