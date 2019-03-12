open Core_kernel
open Import
open Snarky
open Snark_params
open Snark_params.Tick
open Let_syntax
open Currency
open Fold_lib

let coinbase_tree_depth = Snark_params.pending_coinbase_depth

(*Total number of stacks*)
let coinbase_stacks = Int.pow 2 coinbase_tree_depth

module Coinbase_data = struct
  type t = Public_key.Compressed.t * Amount.t [@@deriving sexp]

  let of_coinbase (cb : Coinbase.t) : t Or_error.t =
    Option.value_map cb.fee_transfer
      ~default:(Ok (cb.proposer, cb.amount))
      ~f:(fun (_, fee) ->
        match Currency.Amount.sub cb.amount (Amount.of_fee fee) with
        | None -> Or_error.error_string "Coinbase underflow"
        | Some amount -> Ok (cb.proposer, amount) )

  type var = Public_key.Compressed.var * Amount.var

  type value = t

  let length_in_triples =
    Public_key.Compressed.length_in_triples + Amount.length_in_triples

  let var_of_t ((public_key, amount) : value) =
    (Public_key.Compressed.var_of_t public_key, Amount.var_of_t amount)

  let var_to_triples (public_key, amount) =
    let%map public_key = Public_key.Compressed.var_to_triples public_key in
    let amount = Amount.var_to_triples amount in
    public_key @ amount

  let fold ((public_key, amount) : t) =
    let open Fold in
    Public_key.Compressed.fold public_key +> Amount.fold amount
end

module Stack_id : sig
  type t [@@deriving bin_io, sexp, compare, eq]

  val of_int : int -> t

  val to_int : t -> int

  val zero : t

  val incr_by_one : t -> t option

  val to_string : t -> string
end = struct
  include Int

  let incr_by_one t1 =
    let t2 = t1 + 1 in
    if t2 < t1 then None else Some t2
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

      let digest t =
        var_to_triples t
        >>= Pedersen.Checked.digest_triples ~init:Hash_prefix.coinbase_stack
    end
  end
end

(*Pending coinbase hash*)
module Hash = struct
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
end

module T = struct
  module Stack = struct
    include Coinbase_stack.Stack

    let hash (t : t) = Hash.of_digest (digest t :> field)
  end

  module Merkle_tree =
    Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Stack_id) (Stack)

  module Checked = struct
    open Coinbase_stack

    type var = Hash.var

    module Merkle_tree =
      Snarky.Merkle_tree.Checked
        (Tick)
        (struct
          type value = Pedersen.Checked.Digest.t

          type var = Pedersen.Checked.Digest.var

          let typ = Pedersen.Checked.Digest.typ

          let hash ~height h1 h2 =
            let to_triples (bs : Pedersen.Checked.Digest.Unpacked.var) =
              Bitstring_lib.Bitstring.pad_to_triple_list
                ~default:Boolean.false_
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

    type path = Pedersen.Digest.t list

    module Address = struct
      include Merkle_tree.Address

      let typ = typ ~depth
    end

    type _ Request.t +=
      | Coinbase_stack_path : Address.value -> path Request.t
      | Get_coinbase_stack : Address.value -> (Stack.t * path) Request.t
      | Set_coinbase_stack : Address.value * Stack.t -> unit Request.t
      | Find_index_of_newest_stack : bool -> Address.value Request.t
      | Find_index_of_oldest_stack : Address.value Request.t

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
        (Merkle_tree.get_req ~depth (Hash.var_to_hash_packed t) addr)
        reraise_merkle_requests

    let%snarkydef update_stack t ~is_new_stack stack_before stack_after =
      let%bind addr =
        request_witness Address.typ
          As_prover.(
            map (read Boolean.typ is_new_stack) ~f:(fun s ->
                Find_index_of_newest_stack s ))
      in
      handle
        (Merkle_tree.modify_req ~depth (Hash.var_to_hash_packed t) addr
           ~f:(fun stack ->
             let%map () =
               Coinbase_stack.Stack.assert_equal stack_before stack
             in
             stack_after ))
        reraise_merkle_requests
      >>| Hash.var_of_hash_packed

    let%snarkydef delete_stack t stack_before stack_after =
      let%bind addr =
        request_witness Address.typ
          As_prover.(map (return ()) ~f:(fun _ -> Find_index_of_oldest_stack))
      in
      handle
        (Merkle_tree.modify_req ~depth (Hash.var_to_hash_packed t) addr
           ~f:(fun stack ->
             let%map () =
               Coinbase_stack.Stack.assert_equal stack_before stack
             in
             stack_after ))
        reraise_merkle_requests
      >>| Hash.var_of_hash_packed
  end

  type t = {tree: Merkle_tree.t; pos_list: Stack_id.t list; new_pos: Stack_id.t}
  [@@deriving sexp, bin_io]

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
      if
        Stack_id.compare key (Stack_id.of_int @@ Int.pow 2 coinbase_tree_depth)
        > 0
      then t
      else
        let path =
          create_path (coinbase_tree_depth - 1) [] (Stack_id.to_int key)
        in
        go
          (Merkle_tree.add_path t path key Stack.empty)
          (Option.value_exn
             ~error:(Error.of_string "Stack_id overflowed")
             (Stack_id.incr_by_one key))
    in
    { tree=
        go
          (Merkle_tree.of_hash ~depth:coinbase_tree_depth root_hash)
          Stack_id.zero
    ; pos_list= []
    ; new_pos= Stack_id.zero }

  let merkle_root t = Merkle_tree.merkle_root t.tree

  let empty_merkle_root () = merkle_root (create_exn ())

  let with_next_index_exn t ~is_new_stack =
    if is_new_stack then
      let new_pos =
        if Stack_id.equal t.new_pos (Stack_id.of_int coinbase_stacks) then
          Stack_id.zero
        else
          Option.value_exn
            ~error:(Error.of_string "Stack_id overflowed")
            (Stack_id.incr_by_one t.new_pos)
      in
      {t with pos_list= t.new_pos :: t.pos_list; new_pos}
    else t

  let latest_stack_id t ~is_new_stack =
    if is_new_stack then Some t.new_pos
    else match t.pos_list with [] -> None | x :: _ -> Some x

  let latest_stack_exn t =
    let open Option.Let_syntax in
    let%map key = latest_stack_id t ~is_new_stack:false in
    let index = Merkle_tree.find_index_exn t.tree key in
    Merkle_tree.get_exn t.tree index

  let oldest_stack_id t = List.last t.pos_list

  let remove_oldest_stack_id_exn t =
    match List.rev t with
    | [] -> failwith "No stacks"
    | x :: xs -> (x, List.rev xs)

  let oldest_stack_exn t =
    let key = Option.value ~default:Stack_id.zero (oldest_stack_id t) in
    let index = Merkle_tree.find_index_exn t.tree key in
    Merkle_tree.get_exn t.tree index

  let add_coinbase_exn t ~coinbase ~is_new_stack =
    let key = Option.value_exn (latest_stack_id t ~is_new_stack) in
    let stack_index = Merkle_tree.find_index_exn t.tree key in
    let stack_before = Merkle_tree.get_exn t.tree stack_index in
    let stack_after = Stack.push_exn stack_before coinbase in
    let t' = with_next_index_exn t ~is_new_stack in
    let tree' = Merkle_tree.set_exn t.tree stack_index stack_after in
    {t' with tree= tree'}

  let update_coinbase_stack_exn t stack ~is_new_stack =
    let key = Option.value_exn (latest_stack_id t ~is_new_stack) in
    let stack_index = Merkle_tree.find_index_exn t.tree key in
    let t' = with_next_index_exn t ~is_new_stack in
    let tree' = Merkle_tree.set_exn t.tree stack_index stack in
    {t' with tree= tree'}

  let remove_coinbase_stack_exn t =
    let oldest_stack, remaining = remove_oldest_stack_id_exn t.pos_list in
    let stack_index = Merkle_tree.find_index_exn t.tree oldest_stack in
    let stack = Merkle_tree.get_exn t.tree stack_index in
    let tree' = Merkle_tree.set_exn t.tree stack_index Stack.empty in
    (stack, {t with tree= tree'; pos_list= remaining})

  let hash ({pos_list; new_pos; _} as t) =
    let h = Digestif.SHA256.init () in
    let h = Digestif.SHA256.feed_string h (Hash.to_bytes (merkle_root t)) in
    let h =
      Digestif.SHA256.feed_string h
        (List.fold pos_list ~init:"" ~f:(fun s a -> s ^ Stack_id.to_string a))
    in
    let h = Digestif.SHA256.feed_string h (Stack_id.to_string new_pos) in
    (Digestif.SHA256.get h :> string)

  let get_exn t index = Merkle_tree.get_exn t.tree index

  let path_exn t index = Merkle_tree.path_exn t.tree index

  let set_exn t index stack =
    {t with tree= Merkle_tree.set_exn t.tree index stack}

  let find_index_exn t = Merkle_tree.find_index_exn t.tree

  let handler (t : t) =
    let pending_coinbase = ref t in
    let coinbase_stack_path_exn idx =
      List.map (path_exn !pending_coinbase idx) ~f:(function
        | `Left h -> h
        | `Right h -> h )
    in
    stage (fun (With {request; respond}) ->
        match request with
        | Checked.Coinbase_stack_path idx ->
            let path =
              (coinbase_stack_path_exn idx :> Pedersen.Digest.t list)
            in
            respond (Provide path)
        | Checked.Find_index_of_oldest_stack ->
            let stack_id =
              Option.value ~default:Stack_id.zero
                (oldest_stack_id !pending_coinbase)
            in
            let index = find_index_exn !pending_coinbase stack_id in
            respond (Provide index)
        | Checked.Find_index_of_newest_stack is_new_stack ->
            let stack_id =
              Option.value ~default:Stack_id.zero
                (latest_stack_id !pending_coinbase ~is_new_stack)
            in
            let index = find_index_exn !pending_coinbase stack_id in
            respond (Provide index)
        | Checked.Get_coinbase_stack idx ->
            let elt = get_exn !pending_coinbase idx in
            let path =
              (coinbase_stack_path_exn idx :> Pedersen.Digest.t list)
            in
            respond (Provide (elt, path))
        | Checked.Set_coinbase_stack (idx, stack) ->
            pending_coinbase := set_exn !pending_coinbase idx stack ;
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
                let t = add_coinbase_exn acc ~coinbase ~is_new_stack:!is_new in
                is_new := false ;
                t )
          in
          let _, after_del = remove_coinbase_stack_exn after_adding in
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
          let open Snark_params.Tick in
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
      let unchecked =
        update_coinbase_stack_exn pending_coinbases stack ~is_new_stack:true
      in
      let update = Checked.update_stack in
      let checked =
        let comp =
          let open Snark_params.Tick in
          let stack_var = Stack.(var_of_t stack) in
          let%map res =
            handle
              (update
                 (Hash.var_of_t (merkle_root pending_coinbases))
                 ~is_new_stack:Boolean.true_ Stack.Checked.empty stack_var)
              (unstage (handler pending_coinbases))
          in
          As_prover.read Hash.typ res
        in
        let (), x = Or_error.ok_exn (run_and_check comp ()) in
        x
      in
      assert (Hash.equal (merkle_root unchecked) checked) )
