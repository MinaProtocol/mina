open Core_kernel
open Import
open Snarky
open Snark_params
open Snark_params.Tick
open Let_syntax
open Currency
open Fold_lib
open Snark_bits

module Coinbase_data = struct
  type t = Public_key.Compressed.t * Amount.Signed.t [@@deriving sexp]

  let of_coinbase (cb : Coinbase.t) : t Or_error.t =
    Option.value_map cb.fee_transfer
      ~default:(Ok (cb.proposer, Amount.Signed.of_unsigned cb.amount))
      ~f:(fun (_, fee) ->
        match Currency.Amount.sub cb.amount (Amount.of_fee fee) with
        | None -> Or_error.error_string "Coinbase underflow"
        | Some amount -> Ok (cb.proposer, Amount.Signed.of_unsigned amount) )

  type var = Public_key.Compressed.var * Amount.Signed.var

  type value = t [@@deriving sexp]

  let length_in_triples =
    Public_key.Compressed.length_in_triples + Amount.Signed.length_in_triples

  let typ : (var, value) Typ.t =
    let spec =
      let open Data_spec in
      [Public_key.Compressed.typ; Amount.Signed.typ]
    in
    let of_hlist : 'a 'b. (unit, 'a -> 'b -> unit) H_list.t -> 'a * 'b =
      let open H_list in
      fun [public_key; amount] -> (public_key, amount)
    in
    let to_hlist (public_key, amount) = H_list.[public_key; amount] in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_of_t ((public_key, amount) : value) =
    ( Public_key.Compressed.var_of_t public_key
    , Amount.Signed.Checked.of_unsigned @@ Amount.var_of_t
      @@ Amount.Signed.magnitude amount )

  let var_to_triples (public_key, amount) =
    let%map public_key = Public_key.Compressed.var_to_triples public_key in
    let amount = Amount.Signed.Checked.to_triples amount in
    public_key @ amount

  let fold ((public_key, amount) : t) =
    let open Fold in
    Public_key.Compressed.fold public_key +> Amount.Signed.fold amount

  let crypto_hash_prefix = Hash_prefix.coinbase

  let crypto_hash t = Pedersen.hash_fold crypto_hash_prefix (fold t)

  let empty = (Public_key.Compressed.empty, Amount.zero)

  let digest t = Pedersen.State.digest (crypto_hash t)

  let create public_key amount = (public_key, amount)

  let gen =
    let open Quickcheck.Let_syntax in
    let%bind public_key = Public_key.Compressed.gen in
    let%bind amount = Currency.Amount.gen in
    return (create public_key amount)

  module Checked = struct
    let hash t =
      var_to_triples t
      >>= Pedersen.Checked.hash_triples ~init:crypto_hash_prefix

    let digest t =
      var_to_triples t
      >>= Pedersen.Checked.digest_triples ~init:crypto_hash_prefix
  end
end

let coinbase_stacks = 9

let coinbase_tree_depth = Int.ceil_log2 coinbase_stacks

module Stack_pos = struct
  include Int

  let gen = Int.gen_incl 0 ((1 lsl coinbase_tree_depth) - 1)

  module Vector = struct
    include Int

    let length = coinbase_tree_depth

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold_bits t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

module Coinbase_stack = struct
  module Stack = struct
    include Data_hash.Make_full_size ()

    let push_exn (h : t) cb : t =
      match Coinbase_data.of_coinbase cb with
      | Ok cb ->
          Pedersen.digest_fold Hash_prefix.coinbase_stack
            Fold.(Coinbase_data.fold cb +> fold h)
          |> of_hash
      | Error e ->
          failwithf "Error adding a coinbase to the pending stack: %s"
            (Error.to_string_hum e) ()

    let empty =
      of_hash
        ( Pedersen.(State.salt params ~get_chunk_table "CoinbaseStack")
        |> Pedersen.State.digest )

    let digest t =
      Pedersen.State.digest
        (Pedersen.hash_fold Hash_prefix.coinbase_stack (fold t))

    module Checked = struct
      type t = var

      let push (t : t) (coinbase : Coinbase_data.var) =
        (*Prefix+Coinbase+Current-stack*)
        let init =
          Pedersen.Checked.Section.create
            ~acc:(`Value Hash_prefix.coinbase_stack.acc)
            ~support:
              (Interval_union.of_interval (0, Hash_prefix.length_in_triples))
        in
        let%bind coinbase_section =
          let%bind bs = Coinbase_data.var_to_triples coinbase in
          Pedersen.Checked.Section.extend init bs
            ~start:Hash_prefix.length_in_triples
        in
        let%bind with_t =
          let%bind bs = var_to_triples t in
          Pedersen.Checked.Section.extend Pedersen.Checked.Section.empty bs
            ~start:
              (Hash_prefix.length_in_triples + Coinbase_data.length_in_triples)
        in
        let%map s =
          Pedersen.Checked.Section.disjoint_union_exn coinbase_section with_t
        in
        let digest, _ =
          Pedersen.Checked.Section.to_initial_segment_digest_exn s
        in
        var_of_hash_packed digest

      let if_ = if_

      let empty = var_of_t empty

      let equal (x : var) (y : var) =
        Field.Checked.equal (var_to_hash_packed x) (var_to_hash_packed y)

      let hash t =
        var_to_triples t
        >>= Pedersen.Checked.hash_triples ~init:Hash_prefix.coinbase_stack

      let digest t =
        var_to_triples t
        >>= Pedersen.Checked.digest_triples ~init:Hash_prefix.coinbase_stack
    end
  end
end

(*Pending coinbase hash*)
module Hash = struct
  open Coinbase_stack

  module Merkle_tree =
    Snarky.Merkle_tree.Checked
      (Tick)
      (struct
        type value = Pedersen.Checked.Digest.t [@@deriving sexp]

        type var = Pedersen.Checked.Digest.var

        let typ = Pedersen.Checked.Digest.typ

        let hash ~height h1 h2 =
          let to_triples (bs : Pedersen.Checked.Digest.Unpacked.var) =
            Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_
              (bs :> Boolean.var list)
          in
          let%bind h1 = Pedersen.Checked.Digest.choose_preimage h1
          and h2 = Pedersen.Checked.Digest.choose_preimage h2 in
          Pedersen.Checked.digest_triples
            ~init:Hash_prefix.coinbase_merkle_tree.(height)
            (to_triples h1 @ to_triples h2)

        let assert_equal h1 h2 = Field.Checked.Assert.equal h1 h2

        let if_ = Field.Checked.if_
      end)
      (struct
        include Stack

        type value = t [@@deriving sexp]

        let hash = Checked.digest
      end)

  let depth = coinbase_tree_depth

  include Data_hash.Make_full_size ()

  let merge ~height (h1 : t) (h2 : t) =
    let open Tick.Pedersen in
    State.digest
      (hash_fold
         Hash_prefix.coinbase_merkle_tree.(height)
         Fold.(Digest.fold (h1 :> field) +> Digest.fold (h2 :> field)))
    |> of_hash

  let empty_hash =
    let open Tick.Pedersen in
    digest_fold
      (State.create params ~get_chunk_table)
      (Fold.string_triples "Pending coinbases merkle tree")
    |> of_hash

  let of_digest = Fn.compose Fn.id of_hash

  type path = Pedersen.Digest.t list

  type index = int

  type _ Request.t +=
    | Coinbase_stack_path : index -> path Request.t
    | Get_coinbase_stack : index -> (Stack.t * path) Request.t
    | Set_coinbase_stack : index * Stack.t -> unit Request.t
    | Find_index_of_newest_stack : bool -> index Request.t
    | Find_index_of_oldest_stack : index Request.t
    | Reset : unit Request.t

  let reraise_merkle_requests (With {request; respond}) =
    match request with
    | Merkle_tree.Get_path addr ->
        respond (Delegate (Coinbase_stack_path addr))
    | Merkle_tree.Set (addr, stack) ->
        respond (Delegate (Set_coinbase_stack (addr, stack)))
    | Merkle_tree.Get_element addr ->
        respond (Delegate (Get_coinbase_stack addr))
    | _ -> unhandled

  let get t addr =
    handle
      (Merkle_tree.get_req ~depth (var_to_hash_packed t) addr)
      reraise_merkle_requests

  let reset () = perform As_prover.(return Reset)

  (*
   [modify_stack t pk ~filter ~f] implements the following spec:

   - finds a coinbase stack [stack] in [t] at path [addr] where [filter stack] holds.
     note that the stack is not guaranteed to be in the tree in which case it must
     just have the one coinbase.
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the stack [f stack] at path [addr].
*)
  let%snarkydef update_stack' t ~is_new_stack
      ~(filter : Stack.var -> ('a, _) Checked.t) ~f =
    let%bind addr =
      request_witness Stack_pos.Unpacked.typ
        As_prover.(
          map (read Boolean.typ is_new_stack) ~f:(fun s ->
              Find_index_of_newest_stack s ))
    in
    let%bind updated_tree_hash =
      handle
        (Merkle_tree.modify_req ~depth (var_to_hash_packed t) addr
           ~f:(fun stack ->
             let%bind () = filter stack in
             f stack ))
        reraise_merkle_requests
      >>| var_of_hash_packed
    in
    let%map () = reset () in
    updated_tree_hash

  (*
   [edit_stack t pk ~f] implements the following spec:

   - finds a coinbase stack [stack] in [t] at path [addr] OR it doesn't and is a stack with one coinbase
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the stack [f stack] at path [addr].
*)
  let update_stack t ~update ~is_new_stack ~f =
    update_stack' t ~is_new_stack
      ~filter:(fun _stack ->
        (*let%bind empty_stack =
          Stack.Checked.equal stack Stack.(var_of_t empty)
        in
        let%bind yes = Boolean.((is_new_stack || not empty_stack)) in*)
        (*Boolean.(Assert.is_true update) )*)
        return () )
      ~f:(fun x -> f x)

  let%snarkydef delete_stack t ~delete =
    let filter stack =
      return ()
      (*let%bind empty_stack =
        Stack.Checked.equal stack Stack.(var_of_t empty)
      in
      let%bind delete = Boolean.(delete || not empty_stack) in
      Boolean.(Assert.is_true (delete))*)
    in
    let%bind addr =
      request_witness Stack_pos.Unpacked.typ
        As_prover.(map (return ()) ~f:(fun _ -> Find_index_of_oldest_stack))
    in
    let%bind updated_tree_hash =
      handle
        (Merkle_tree.modify_req ~depth (var_to_hash_packed t) addr
           ~f:(fun stack ->
             let%map () = filter stack in
             Stack.Checked.empty ))
        reraise_merkle_requests
      >>| var_of_hash_packed
    in
    let%map () = reset () in
    updated_tree_hash

  let%snarkydef update_delete_stack t ~is_new_stack ~stack =
    let%bind addr =
      request_witness Stack_pos.Unpacked.typ
        As_prover.(
          map (read Boolean.typ is_new_stack) ~f:(fun s ->
              Find_index_of_newest_stack s ))
    in
    let%bind updated_tree_hash1 =
      handle
        (Merkle_tree.modify_req ~depth (var_to_hash_packed t) addr
           ~f:(fun _s -> return stack ))
        reraise_merkle_requests
      >>| var_of_hash_packed
    in
    let%bind updated_tree_hash2 =
      let%bind addr =
        request_witness Stack_pos.Unpacked.typ
          As_prover.(map (return ()) ~f:(fun _ -> Find_index_of_oldest_stack))
      in
      handle
        (Merkle_tree.modify_req ~depth (var_to_hash_packed updated_tree_hash1)
           addr ~f:(fun _stack -> return Stack.Checked.empty ))
        reraise_merkle_requests
      >>| var_of_hash_packed
    in
    let%map () = reset () in
    updated_tree_hash2
end

module T = struct
  module Stack = struct
    include Coinbase_stack.Stack

    let hash (t : t) = Hash.of_digest (digest t :> field)
  end

  module Merkle_tree =
    Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Stack_pos) (Stack)

  type t =
    {tree: Merkle_tree.t; pos_list: Stack_pos.t list; new_pos: Stack_pos.t}
  [@@deriving sexp, bin_io]

  let copy = Fn.id

  let create_exn () =
    let init_hash = Stack.hash Stack.empty in
    let hash_on_level, root_hash =
      List.fold
        (List.init coinbase_tree_depth ~f:(fun i -> i + 1))
        ~init:([(0, init_hash)], init_hash)
        ~f:(fun (hashes, cur_hash) height ->
          let merge = Hash.merge ~height:(height - 1) cur_hash cur_hash in
          ((height, merge) :: hashes, merge) )
    in
    let rec create_path height path key =
      if height < 0 then path
      else
        let hash =
          Option.value_exn
            (List.Assoc.find ~equal:Int.equal hash_on_level height)
        in
        create_path (height - 1)
          ((if key mod 2 = 0 then `Left hash else `Right hash) :: path)
          (key / 2)
    in
    let rec go t key =
      if key > Int.pow 2 coinbase_tree_depth then t
      else
        let path = create_path (coinbase_tree_depth - 1) [] key in
        go (Merkle_tree.add_path t path key Stack.empty) (key + 1)
    in
    { tree= go (Merkle_tree.of_hash ~depth:coinbase_tree_depth root_hash) 0
    ; pos_list= []
    ; new_pos= 0 }

  let empty_hash = Merkle_tree.merkle_root (create_exn ()).tree

  (*{tree=Merkle_tree.of_hash ~depth:coinbase_tree_depth h; pos_list=[]; new_pos=0}*)

  let next_new_index t ~on_new_tree =
    if on_new_tree then
      let new_pos = if t.new_pos = coinbase_stacks then 0 else t.new_pos + 1 in
      {t with pos_list= t.new_pos :: t.pos_list; new_pos}
    else t

  let latest_stack_key t ~on_new_tree =
    if on_new_tree then Some t.new_pos
      (* IMPORTANT TODO: include hash of the path*)
    else match t.pos_list with [] -> None | x :: _ -> Some x

  let latest_stack t =
    let open Option.Let_syntax in
    let%map key = latest_stack_key t ~on_new_tree:false in
    let index = Merkle_tree.find_index_exn t.tree key in
    Merkle_tree.get_exn t.tree index

  let oldest_stack_key t = List.last t.pos_list

  let replace_latest_stack t stack ~on_new_tree =
    match t.pos_list with
    | [] -> if on_new_tree then Some [stack] else None
    | x :: xs ->
        if on_new_tree then Some (stack :: x :: xs) else Some (stack :: xs)

  let remove_oldest_stack_exn t =
    match List.rev t with
    | [] -> failwith "No stacks"
    | x :: xs -> (x, List.rev xs)

  let add_coinbase_exn t ~coinbase ~on_new_tree =
    let key = Option.value_exn (latest_stack_key t ~on_new_tree) in
    let stack_index = Merkle_tree.find_index_exn t.tree key in
    let stack_before = Merkle_tree.get_exn t.tree stack_index in
    let stack_after = Stack.push_exn stack_before coinbase in
    let t' = next_new_index t ~on_new_tree in
    let tree' = Merkle_tree.set_exn t.tree stack_index stack_after in
    {t' with tree= tree'}

  let update_coinbase_stack_exn t stack ~new_stack =
    let key = Option.value_exn (latest_stack_key t ~on_new_tree:new_stack) in
    let stack_index = Merkle_tree.find_index_exn t.tree key in
    let t' = next_new_index t ~on_new_tree:new_stack in
    let tree' = Merkle_tree.set_exn t.tree stack_index stack in
    {t' with tree= tree'}

  let remove_coinbase_stack_exn t =
    let oldest_stack, remaining = remove_oldest_stack_exn t.pos_list in
    let stack_index = Merkle_tree.find_index_exn t.tree oldest_stack in
    let tree' = Merkle_tree.set_exn t.tree stack_index Stack.empty in
    {t with tree= tree'; pos_list= remaining}

  let merkle_root t = Merkle_tree.merkle_root t.tree

  let get_exn t index = Merkle_tree.get_exn t.tree index

  let path_exn t index = Merkle_tree.path_exn t.tree index

  let set_exn t index stack =
    {t with tree= Merkle_tree.set_exn t.tree index stack}

  let find_index_exn t = Merkle_tree.find_index_exn t.tree

  type set_unset_tree = {mutable in_use: t; back_up: t}

  let handler (t : t) =
    let pending_coinbase = {in_use= t; back_up= t} in
    let coinbase_stack_path_exn idx =
      List.map (path_exn pending_coinbase.in_use idx) ~f:(function
        | `Left h -> h
        | `Right h -> h )
    in
    Core.printf
      !"PC merkle root: %{sexp: Hash.t} Empty stack: %{sexp:Hash.t}\n %!"
      (merkle_root pending_coinbase.in_use)
      (Stack.hash Stack.empty) ;
    stage (fun (With {request; respond}) ->
        match request with
        | Hash.Coinbase_stack_path idx ->
            let path =
              (coinbase_stack_path_exn idx :> Pedersen.Digest.t list)
            in
            respond (Provide path)
        | Hash.Find_index_of_oldest_stack ->
            let stack_pos =
              Option.value ~default:0
                (oldest_stack_key pending_coinbase.in_use)
            in
            let index = find_index_exn pending_coinbase.in_use stack_pos in
            respond (Provide index)
        | Hash.Find_index_of_newest_stack is_new_stack ->
            let stack_pos =
              Option.value ~default:0
                (latest_stack_key pending_coinbase.in_use
                   ~on_new_tree:is_new_stack)
            in
            let index = find_index_exn pending_coinbase.in_use stack_pos in
            Core.printf !"newest stack pos: %d index:%d\n %!" stack_pos index ;
            respond (Provide index)
        | Hash.Get_coinbase_stack idx ->
            let elt = get_exn pending_coinbase.in_use idx in
            let path =
              (coinbase_stack_path_exn idx :> Pedersen.Digest.t list)
            in
            (*let implied_root entry_hash addr0 path0 =
            let rec go height acc addr path =
              match (addr, path) with
              | [], [] -> return acc
              | b :: bs, h :: hs ->
                  let l = if b then h  else acc in
                  let r = if b then acc else h in
                  let acc' = Hash.merge ~height l r in
                  go (height + 1) acc' bs hs
              | _, _ ->
                  failwith
                    "Merkle_tree.Checked.implied_root: address, path length mismatch"
            in
            go 0 entry_hash addr0 path0
          in
          Core.printf !"implied root: %{sexp: Hash.t} \n %!" (implied_root (merkle_root !pending_coinbase) (Stack_pos.idx path);*)
            respond (Provide (elt, path))
        | Hash.Set_coinbase_stack (idx, stack) ->
            pending_coinbase.in_use
            <- set_exn pending_coinbase.in_use idx stack ;
            respond (Provide ())
        | Hash.Reset ->
            pending_coinbase.in_use <- pending_coinbase.back_up ;
            respond (Provide ())
        | _ -> unhandled )
end

include T

let%test_unit "add stack + remove stack = initial tree " =
  let pending_coinbases = ref (create_exn ()) in
  let coinbases_gen =
    Quickcheck.Generator.tuple2
      (List.gen_with_length 20 Coinbase.gen)
      (Int.gen_incl 1 coinbase_stacks)
  in
  Quickcheck.test coinbases_gen ~trials:10 ~f:(fun (cbs, _i) ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          let is_new = ref true in
          let init = merkle_root !pending_coinbases in
          let after_adding =
            List.fold cbs ~init:!pending_coinbases ~f:(fun acc coinbase ->
                let t = add_coinbase_exn acc ~coinbase ~on_new_tree:!is_new in
                is_new := false ;
                t )
          in
          let after_del = remove_coinbase_stack_exn after_adding in
          pending_coinbases := after_del ;
          assert (Hash.equal (merkle_root after_del) init) ;
          Async.Deferred.return () ) )

let%test_unit "Checked_stack = Unchecked_stack" =
  let open Quickcheck in
  test ~trials:20 (Generator.tuple2 Stack.gen Coinbase.gen)
    ~f:(fun (base, cb) ->
      let unchecked = Stack.push_exn base cb in
      let checked =
        let comp =
          let open Snark_params.Tick.Let_syntax in
          let cb_var =
            Coinbase_data.(var_of_t @@ Or_error.ok_exn @@ of_coinbase cb)
          in
          let%map res = Stack.Checked.push (Stack.var_of_t base) cb_var in
          As_prover.read Stack.typ res
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (Stack.equal unchecked checked) )

let%test_unit "Checked_tree = Unchecked_tree" =
  let open Quickcheck in
  let pending_coinbases = create_exn () in
  test ~trials:20 Stack.gen ~f:(fun stack ->
      Core.printf
        !"PC merkle root trial: %{sexp: Hash.t} \n %!"
        (merkle_root pending_coinbases) ;
      let unchecked =
        update_coinbase_stack_exn pending_coinbases stack ~new_stack:true
      in
      let checked =
        let comp =
          let open Snark_params.Tick.Let_syntax in
          let stack_var = Stack.(var_of_t stack) in
          let%map res =
            handle
              (Hash.update_stack
                 (Hash.var_of_t (merkle_root pending_coinbases))
                 ~update:Boolean.true_ ~is_new_stack:Boolean.true_
                 ~f:(fun _ -> return stack_var))
              (unstage (handler pending_coinbases))
          in
          As_prover.read Hash.typ res
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (Hash.equal (merkle_root unchecked) checked) )
