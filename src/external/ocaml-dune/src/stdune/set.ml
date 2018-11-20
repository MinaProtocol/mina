module type S = Set_intf.S

module Make(Elt : Comparable.S) : S with type elt = Elt.t = struct
  module M = MoreLabels.Set.Make(struct
      type t = Elt.t
      let compare a b = Ordering.to_int (Elt.compare a b)
    end)

  include struct
    [@@@warning "-32"]
    (* [map] is only available since 4.04 *)
    let map ~f t =
      M.elements t
      |> List.map ~f
      |> M.of_list

    (* Since 4.05 *)
    let to_opt f t =
      match f t with
      | x -> Some x
      | exception Not_found -> None
    let choose_opt  = to_opt M.choose
    let min_elt_opt = to_opt M.min_elt
    let max_elt_opt = to_opt M.max_elt
  end

  include M

  let to_list = elements

  let mem t x = mem x t
  let add t x = add x t
  let remove t x = remove x t
  let compare a b = Ordering.of_int (compare a b)
  let is_subset t ~of_ = subset t of_
  let iter t ~f = iter t ~f
  let map t ~f = map t ~f
  let fold t ~init ~f = fold t ~init ~f
  let for_all t ~f = for_all t ~f
  let exists t ~f = exists t ~f
  let filter t ~f = filter t ~f
  let partition t ~f = partition t ~f
  let min_elt = min_elt_opt
  let max_elt = max_elt_opt
  let choose = choose_opt
  let split x t = split t x
end

let to_sexp to_list f t =
  Sexp.Encoder.list f (to_list t)
