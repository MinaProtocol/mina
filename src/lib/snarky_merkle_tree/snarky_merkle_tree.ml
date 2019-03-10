open Snarky
open Core

module Index = struct
  type 'f t = 'f Cvar.t Boolean.t list
end

type ('h, 'a) t = {depth: int; root: 'h}

module type S = sig
  module M : Snark_intf.Run

  module Hash : sig
    type t

    type value
  end

  module Elt : sig
    type t

    type value
  end

  module Index : sig
    type t = M.field Index.t

    type value = int

    val typ : depth:int -> (t, value) M.Typ.t
  end

  type nonrec t = (Hash.t, Elt.t) t

  val root : t -> Hash.t

  val create : depth:int -> root:Hash.t -> t

  val modify : t -> Index.t -> f:(Elt.t -> Elt.t) -> t

  type _ Request.t +=
    | Get_element : Index.value -> (Elt.value * Hash.value list) Request.t
    | Get_path : Index.value -> Hash.value list Request.t
    | Set : Index.value * Elt.value -> unit Request.t
end

module Make
    (M : Snark_intf.Run) (Hash : sig
        type t

        type value

        val typ : (t, value) M.Typ.t

        val compress : height:int -> t -> t -> t

        val if_ : M.Boolean.var -> then_:t -> else_:t -> t

        module Assert : sig
          val equal : t -> t -> unit
        end
    end) (Elt : sig
      type t

      type value

      val typ : (t, value) M.Typ.t

      val hash : t -> Hash.t
    end) =
struct
  type nonrec t = (Hash.t, Elt.t) t

  let root t = t.root

  module Index = struct
    open M

    type t = field Index.t

    type value = int

    let of_int ~depth n : bool list =
      List.init depth ~f:(fun i -> n land (1 lsl i) <> 0)

    let typ ~depth : (t, value) Typ.t =
      Typ.transport
        (Typ.list ~length:depth Boolean.typ)
        ~there:(of_int ~depth)
        ~back:
          (List.foldi ~init:0 ~f:(fun i acc b ->
               if b then acc lor (1 lsl i) else acc ))
  end

  let create ~depth ~root = {root; depth}

  type _ Request.t +=
    | Get_element : Index.value -> (Elt.value * Hash.value list) Request.t
    | Get_path : Index.value -> Hash.value list Request.t
    | Set : Index.value * Elt.value -> unit Request.t

  open M

  let implied_root entry_hash addr0 path0 =
    let rec go height acc addr path =
      match (addr, path) with
      | [], [] -> acc
      | b :: bs, h :: hs ->
          let l = Hash.if_ b ~then_:h ~else_:acc
          and r = Hash.if_ b ~then_:acc ~else_:h in
          let acc' = Hash.compress ~height l r in
          go (height + 1) acc' bs hs
      | _, _ ->
          failwith "Merkle_tree.implied_root: address, path length mismatch"
    in
    go 0 entry_hash addr0 path0

  let modify t idx ~f =
    let prev, prev_path =
      exists
        Typ.(Elt.typ * list ~length:t.depth Hash.typ)
        ~request:
          As_prover.(
            map
              (read (Index.typ ~depth:t.depth) idx)
              ~f:(fun i -> Get_element i))
    in
    (let prev_entry_hash = Elt.hash prev in
     Hash.Assert.equal t.root (implied_root prev_entry_hash idx prev_path)) ;
    let next = f prev in
    let next_entry_hash = Elt.hash next in
    perform
      (let open As_prover in
      let open Let_syntax in
      let%map addr = read (Index.typ ~depth:t.depth) idx
      and next = read Elt.typ next in
      Set (addr, next)) ;
    {root= implied_root next_entry_hash idx prev_path; depth= t.depth}
end
