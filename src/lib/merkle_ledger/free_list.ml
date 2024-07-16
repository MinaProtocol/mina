module type S = sig
  type t [@@deriving sexp]

  type location

  val serialize : ledger_depth:int -> t -> Bigstring.t

  val empty : t

  module Location : sig
    val add : t -> location -> t

    val pop : t -> (location * t) option

    val top : t -> location option

    val mem : t -> location -> bool

    val remove_all_contiguous : t -> location -> t * location option
  end
end

module Make (L : Location_intf.S) : S with type location = L.t = struct
  module Addr = L.Addr
  include Set.Make (L.Addr)

  type location = L.t

  (* [remove_all_contiguous set addr] removes all addresses contiguous from
     [a] in decreasing order.

     @return  a set where all such addresses have been removed, and the first
     address not in set, if any
  *)
  let rec remove_all_contiguous set addr =
    if mem set addr then
      let set = remove set addr in
      let addr = Addr.prev addr in
      match addr with
      | None ->
          (set, addr)
      | Some addr ->
          remove_all_contiguous set addr
    else (set, Some addr)

  let serialize ~ledger_depth t =
    to_list t |> List.map ~f:(Addr.serialize ~ledger_depth) |> Bigstring.concat

  module Location = struct
    (* The free list should only contain addresses that locate accounts *)
    let add set = function
      | L.Account addr ->
          add set addr
      | Generic _bigstring ->
          invalid_arg "Free_list.add_location: cannot add generic"
      | Hash _ ->
          invalid_arg "Free_list.add_location: cannot add hash"

    let account addr = L.Account addr

    let top = max_elt

    let pop set =
      Option.map ~f:(fun addr -> (account addr, remove set addr)) (top set)

    let top set = Option.map ~f:account (top set)

    let mem set = function
      | L.Account addr ->
          mem set addr
      | Generic _ | Hash _ ->
          false

    let remove_all_contiguous set = function
      | L.Account addr ->
          let set, addr = remove_all_contiguous set addr in
          (set, Option.map ~f:account addr)
      | Generic _bigstring ->
          invalid_arg "Free_list.add_location: cannot add generic"
      | Hash _ ->
          invalid_arg "Free_list.add_location: cannot add hash"
  end
end
