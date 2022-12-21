open Core_kernel

module type Inputs_intf = sig
  type proof_elem

  type hash [@@deriving equal]

  val hash : hash -> proof_elem -> hash
end

module Make_intf (Input : Inputs_intf) = struct
  module type S = sig
    val verify :
         init:Input.hash
      -> Input.proof_elem list
      -> Input.hash
      -> Input.hash Mina_stdlib.Nonempty_list.t option

    val verify_right :
         init:Input.hash
      -> Input.proof_elem list
      -> Input.hash
      -> Input.hash Mina_stdlib.Nonempty_list.t option
  end
end

module Make (Input : Inputs_intf) : Make_intf(Input).S = struct
  open Input

  (* TODO: probably [verify_right] is the right thing in most cases, because we want
     hashes to start with that, as we build up a list; the default left fold combines
     the init hash with the head element

     leaving the default [verify] because it's used a few places in the code
  *)
  let verify, verify_right =
    let conser acc proof_elem =
      Mina_stdlib.Nonempty_list.cons
        (hash (Mina_stdlib.Nonempty_list.head acc) proof_elem)
        acc
    in
    let verify ~init merkle_list target_hash =
      let hashes =
        List.fold merkle_list
          ~init:(Mina_stdlib.Nonempty_list.singleton init)
          ~f:conser
      in
      if equal_hash target_hash (Mina_stdlib.Nonempty_list.head hashes) then
        Some hashes
      else None
    in
    let verify_right ~init merkle_list target_hash =
      let hashes =
        List.fold_right merkle_list
          ~init:(Mina_stdlib.Nonempty_list.singleton init)
          ~f:(Fn.flip conser)
      in
      if equal_hash target_hash (Mina_stdlib.Nonempty_list.head hashes) then
        Some hashes
      else None
    in
    (verify, verify_right)
end
