module Four = struct
  type t =
  | Zero
  | One 
  | Two
  | Three
end

module Triple = struct
  type 'a t = 'a * 'a * 'a


(* even though if false false gives 'zero' 
  we have +0 and -0 such that +g0 = -(-g0) *)

  let get (b : bool t) =
    let (s0, s1, s2) = b in
      match s0, s1 with
      | false, false -> Four.Zero
      | true, false -> Four.One
      | false, true -> Four.Two
      | true, true -> Four.Three
end

module Quadruple = struct
  type 'a t = 'a * 'a * 'a * 'a

  let get (quad : 'a t) (index : Four.t) = 
    let (g0, g1, g2, g3) = quad in
      match index with 
      | Zero -> g0
      | One -> g1
      | Two -> g2
      | Three -> g3
end

  type ('s, 'b) fold =
       init:'s -> f:('s -> 'b -> 's) -> 's

  type 'b poly_fold = { fold : 's. ('s, 'b) fold }

  type bit_fold = bool poly_fold

  type triple_fold = bool Triple.t poly_fold

  let triple_fold_of_bit_fold (fold : bit_fold) : triple_fold =
  { fold =
    fun ~init ~f ->
      let (pt, bs) =
        fold.fold ~init:(init, []) ~f:(fun (pt, bs) b ->
          match bs with 
          | [b2; b1; b0] ->
          let pt' = f pt (b0, b1, b2) in 
          (pt', [])
          | _ ->
            (pt, b :: bs))
      in 
      match bs with
      | [b2; b1; b0] -> f pt (b0, b1, b2)
      | [b1; b0] ->  f pt (b0, b1, false)
      | [b0] -> f pt (b0, false, false)
      | [] -> pt
      | _::_::_ -> pt
  }