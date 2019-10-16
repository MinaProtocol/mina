open Core_kernel
module Crypto = Crypto
open Crypto

module Hash = struct
  let params = Sponge_params.params

  module Input = struct
    type ('field, 'bool) t =
      {field_elements: 'field array; bitstrings: 'bool list array}

    let append t1 t2 =
      { field_elements= Array.append t1.field_elements t2.field_elements
      ; bitstrings= Array.append t1.bitstrings t2.bitstrings }

    let field_elements x = {field_elements= x; bitstrings= [||]}

    let field x = {field_elements= [|x|]; bitstrings= [||]}

    let bitstring x = {field_elements= [||]; bitstrings= [|x|]}

    let bitstrings x = {field_elements= [||]; bitstrings= x}
  end

  let pack_input ~project {Input.field_elements; bitstrings} =
    let packed_bits =
      let xs, final, len_final =
        Array.fold bitstrings ~init:([], [], 0)
          ~f:(fun (acc, curr, n) bitstring ->
            let k = List.length bitstring in
            let n' = k + n in
            if n' >= Field.size_in_bits then (project curr :: acc, bitstring, k)
            else (acc, bitstring @ curr, n') )
      in
      if len_final = 0 then xs else project final :: xs
    in
    Array.append field_elements (Array.of_list_rev packed_bits)

  module Digest : sig
    type t = Field.t [@@deriving bin_io, eq, compare, to_yojson, sexp]

    open Run

    module Checked : sig
      type t = Field.t

      val if_ : Boolean.var -> then_:t -> else_:t -> t

      val assert_equal : t -> t -> unit
    end

    val typ : (Checked.t, t) Typ.t
  end  = struct
    type t = Field.t [@@deriving bin_io, eq, compare, sexp]

    let to_yojson x = `String (Field.to_string x)

      open Run
    module Checked = struct

      type t = Field.t

      let if_ = Field.if_

      let assert_equal = Field.Assert.equal
    end

    let typ = Field.typ
  end


  module Rounds = struct
    let rounds_full = 8
    let rounds_partial = 83
  end

  module Inputs = struct
    include Rounds
    module Field = Field

    let alpha = 5

    let to_the_alpha x =
      let open Field in
      let res = x + zero in
      res *= res ;
      (* x^2 *)
      res *= res ;
      (* x^4 *)
      res *= x ;
      (* x^5 *)
      res

    module Operations = struct
      let apply_matrix rows v =
        Array.map rows ~f:(fun row ->
            let open Field in
            let res = zero + zero in
            Array.iteri row ~f:(fun i r -> res += (r * v.(i))) ;
            res )

      let add_block ~state block =
        Array.iteri block ~f:(fun i b ->
            let open Field in
            state.(i) += b )

      (* TODO: Have an explicit function for making a copy of a field element. *)
      let copy a = Array.map a ~f:(fun x -> Field.(x + zero))
    end
  end

  include Sponge.Make(Sponge.Poseidon(Inputs))

  let update ~state = update ~state params

  let hash ?init = hash ?init params

  module Checked = struct
    module Inputs = struct
      include Rounds
      module Field = struct
        (* The linear combinations involved in computing Poseidon do not involve very many
    variables, but if they are represented as arithmetic expressions (that is, "Cvars"
    which is what Field.t is under the hood) the expressions grow exponentially in
    in the number of rounds. Thus, we compute with Field elements represented by
    a "reduced" linear combination. That is, a coefficient for each variable and an
    constant term.
  *)
        type t = Field.t Int.Map.t * Field.t

        let to_cvar ((m, c) : t) : Field.Var.t =
          Map.fold m ~init:(Field.Var.constant c) ~f:(fun ~key ~data acc ->
              let x =
                let v = Snarky.Cvar.Var key in
                if Field.equal data Field.one then v else Scale (data, v)
              in
              match acc with
              | Constant c when Field.equal Field.zero c ->
                  x
              | _ ->
                  Add (x, acc) )

        let constant c = (Int.Map.empty, c)

        let of_cvar (x : Field.Var.t) =
          match x with
          | Constant c ->
              constant c
          | Var v ->
              (Int.Map.singleton v Field.one, Field.zero)
          | x ->
              let c, ts = Field.Var.to_constant_and_terms x in
              ( Int.Map.of_alist_reduce
                  (List.map ts ~f:(fun (f, v) -> (Backend.Var.index v, f)))
                  ~f:Field.add
              , Option.value ~default:Field.zero c )

        let ( + ) (t1, c1) (t2, c2) =
          ( Map.merge t1 t2 ~f:(fun ~key:_ t ->
                match t with
                | `Left x ->
                    Some x
                | `Right y ->
                    Some y
                | `Both (x, y) ->
                    Some Field.(x + y) )
          , Field.add c1 c2 )

        let ( * ) (t1, c1) (t2, c2) =
          assert (Int.Map.is_empty t1) ;
          (Map.map t2 ~f:(Field.mul c1), Field.mul c1 c2)

        let zero = constant Field.zero
      end

      let to_the_alpha x =
        let open Run.Field in
        let zero = square in
        let one a = square a * x in
        let one' = x in
        one' |> zero |> one

      let to_the_alpha x = Field.of_cvar (to_the_alpha (Field.to_cvar x))

      module Operations = Sponge.Make_operations (Field)
    end
    include Sponge.Make(Sponge.Poseidon(Inputs))

    type t = Field.Var.t

    let params = Sponge.Params.map ~f:Inputs.Field.constant params

    open Inputs.Field

    let update ~state xs =
      let f = Array.map ~f:of_cvar in
      update params ~state:(f state) (f xs) |> Array.map ~f:to_cvar

    let hash ?init xs =
      hash
        ?init:(Option.map init ~f:(Sponge.State.map ~f:constant))
        params (Array.map xs ~f:of_cvar)
      |> to_cvar

    let pack_input = pack_input ~project:Run.Field.project

    let initial_state = Array.map initial_state ~f:to_cvar

    let digest xs = xs.(0)
  end

let pack_input = pack_input ~project:Field.project
end

module Merkle_tree (Elt : sig
    type t [@@deriving bin_io, eq, sexp, to_yojson, compare]

    val hash : t -> Hash.Digest.t

    module Checked : sig
      type t
      val hash : t -> Hash.Digest.Checked.t
    end
end) = struct
  module Root = Hash

  open Run

  module Index = struct
    type t = int

    let to_bits ~depth n =
      let test_bit n i = (n lsl i) land 1 = 1 in
      List.init depth
        ~f:(fun i -> test_bit n (depth - 1 - i ) )

    module Checked = struct
      (* MSB first *)
      type t = Boolean.var list
    end

    let typ ~depth =
      Typ.transport
        (Typ.list ~length:depth Boolean.typ)
        ~there:(to_bits ~depth)
        ~back:(fun bits ->
            List.fold_left bits ~init:0 ~f:(fun acc b ->
              (acc lsl 1) lor (if b then 1 else 0) ) )
  end

  module Checked = struct
    let merge ~height:_ l r =
      Hash.Checked.(hash [| l; r |])

    let implied_root entry_hash addr0 path0 =
      let rec go height acc addr path =
        match (addr, path) with
        | [], [] ->
            acc
        | b :: bs, h :: hs ->
            let l = Hash.Digest.Checked.if_ b ~then_:h ~else_:acc
            and r = Hash.Digest.Checked.if_ b ~then_:acc ~else_:h in
            let acc' = merge ~height l r in
            go (height + 1) acc' bs hs
        | _, _ ->
            failwith
              "Merkle_tree.Checked.implied_root: address, path length mismatch"
      in
      go 0 entry_hash addr0 path0

    let check_membership ~root elt index path =
      Hash.Digest.Checked.assert_equal
        (implied_root (Elt.Checked.hash elt) index path)
        root
  end

      let merge ~height:_ l r =
        Hash.hash [| l; r |]
  include Sparse_ledger_lib.Sparse_ledger.Make(struct
      include Hash.Digest
      let __versioned__ = ()

    (* TODO: Prefix with height *)
      let merge = merge
    end)(struct
      include Unit
      let to_yojson () = `String "()"
      let __versioned__ = ()
    end)
      (struct
        include Elt
        let data_hash = hash
        let __versioned__ = ()
      end)

  open Sparse_ledger_lib.Sparse_ledger

  let implied_root entry_hash addr0 path0 =
    let rec go height acc addr path =
      match (addr, path) with
      | [], [] ->
          acc
      | b :: bs, h :: hs ->
          let l = if b then h else acc
          and r = if b then acc else h in
          let acc' = merge ~height l r in
          go (height + 1) acc' bs hs
      | _, _ ->
          failwith
            "Merkle_tree.Checked.implied_root: address, path length mismatch"
    in
    go 0 entry_hash (Index.to_bits ~depth:(List.length path0) addr0) path0

  let hash_tree : (Hash.Digest.t, Elt.t) Poly.Tree.t -> Hash.Digest.t = function
    | Account a ->
        Elt.hash a
    | Hash h ->
        h
    | Node (h, _, _) ->
        h

  let of_list ~default leaves0 =
    let leaves = 
      let n = List.length leaves0 in
      let padding = (1 lsl Int.ceil_pow2 n) - n in
      leaves0 @ List.init padding ~f:(fun _ -> default)
    in
    let rec pair_up acc = function
      | [] -> List.rev acc
      | x :: y :: xs -> pair_up ((x, y) :: acc) xs
      | _ -> assert false
    in
    let rec go height (trees : _ Poly.Tree.t list) =
      match trees with
      | [ r ] -> (r, height)
      | _ :: _ ->
        let merged =
          List.map (pair_up [] trees) ~f:(fun (l, r) ->
              Poly.Tree.Node (
                merge ~height (hash_tree l) (hash_tree r)
                            , l, r) )
        in
        go (height + 1) merged
      | [] -> assert false
    in
    let tree, height = 
      go 0 (List.map leaves ~f:(fun l -> Poly.Tree.Account l))
    in
    { Poly.indexes = []
    ; depth = height
    ; tree }
end
