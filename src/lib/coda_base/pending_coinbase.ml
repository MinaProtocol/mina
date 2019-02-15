open Core_kernel
open Import
open Snark_params
open Snarky
open Tick
open Let_syntax
open Currency
open Fold_lib
open Snark_bits

module Coinbase = struct
  type t = Public_key.Compressed.t * Currency.Amount.t [@@deriving sexp]

  let of_coinbase (cb : Coinbase.t) : t Or_error.t =
    Option.value_map cb.fee_transfer
      ~default:(Ok (cb.proposer, cb.amount))
      ~f:(fun (_, fee) ->
        match Currency.Amount.sub cb.amount (Currency.Amount.of_fee fee) with
        | None -> Or_error.error_string "Coinbase underflow"
        | Some amount -> Ok (cb.proposer, amount) )

  type var = Public_key.Compressed.var * Amount.var

  type value = Public_key.Compressed.t * Amount.t [@@deriving sexp]

  let typ : (var, value) Typ.t =
    let spec =
      let open Data_spec in
      [Public_key.Compressed.typ; Amount.typ]
    in
    let of_hlist : 'a 'b. (unit, 'a -> 'b -> unit) H_list.t -> 'a * 'b =
      let open H_list in
      fun [public_key; amount] -> (public_key, amount)
    in
    let to_hlist (public_key, amount) = H_list.[public_key; amount] in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_of_t ((public_key, amount) : value) =
    (Public_key.Compressed.var_of_t public_key, Amount.var_of_t amount)

  let var_to_triples (public_key, amount) =
    let%map public_key = Public_key.Compressed.var_to_triples public_key in
    let amount = Amount.var_to_triples amount in
    public_key @ amount

  let fold ((public_key, amount) : t) =
    let open Fold in
    Public_key.Compressed.fold public_key +> Amount.fold amount

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

let coinbase_stacks = Int.ceil_log2 9

module Index = struct
  include Int

  let gen = Int.gen_incl 0 ((1 lsl coinbase_stacks) - 1)

  module Vector = struct
    include Int

    let length = coinbase_stacks

    let empty = zero

    let get t i = (t lsr i) land 1 = 1

    let set v i b = if b then v lor (one lsl i) else v land lnot (one lsl i)
  end

  include (Bits.Vector.Make (Vector) : Bits_intf.S with type t := t)

  let fold_bits = fold

  let fold t = Fold.group3 ~default:false (fold_bits t)

  include Bits.Snarkable.Small_bit_vector (Tick) (Vector)
end

(*module Ordered_collection : sig
  type 'a t

  val update : 'a t -> ('a -> 'a) -> 'a t

  val delete : 'a t -> ('a -> 'a) -> 'a t

  (*create*)
end = struct
  type 'a t = {data: (Pedersen.Digest.t, 'a) Merkle_tree.t
  ;delete_at: Index.t (* set empty here and *)
  ;update_at: Index.t}

  let update _ _ = failwith ""

  let delete _ _ = failwith ""
end*)

(*module Stack = struct
  type t = Pedersen.Digest.t * 

  let equal = Pedersen.Digest.equal

  let hash _ = failwith ""

  let to_bits _ = failwith ""

  let push t x = hash (to_bits t @ to_bits x)
end*)

module Stack = struct
  include Data_hash.Make_full_size ()

  let push_exn (h : t) cb : t =
    match Coinbase.of_coinbase cb with
    | Ok cb ->
        Pedersen.digest_fold Hash_prefix.coinbase_stack
          Fold.(fold h +> Coinbase.fold cb)
        |> of_hash
    | Error e ->
        failwithf "Error adding a coinbase to the pending stack: %s"
          (Error.to_string_hum e) ()

  (*let equal t1 t2= Pedersen.Digest.equal (t1 :> field) (t2 :> field)*)
  
  (*let crypto_hash_prefix = Hash_prefix.account

  let crypto_hash t = Pedersen.hash_fold crypto_hash_prefix (fold_bits t)

  let digest t = Pedersen.State.digest (crypto_hash t)*)

  let empty =
    of_hash
      ( Pedersen.(State.salt params ~get_chunk_table "CoinbaseStack")
      |> Pedersen.State.digest )

  module Checked = struct
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

(*Pending coinbase hash*)
module Hash = struct
  module Merkle_tree =
    Snarky.Merkle_tree.Checked
      (Tick)
      (struct
        type value = Pedersen.Checked.Digest.t

        type var = Pedersen.Checked.Digest.var

        let typ = Pedersen.Checked.Digest.typ

        let hash ~height h1 h2 =
          let to_triples (bs : Pedersen.Checked.Digest.Unpacked.var) =
            Bitstring_lib.Bitstring.pad_to_triple_list ~default:Boolean.false_
              (bs :> Boolean.var list)
          in
          let open Let_syntax in
          (* TODO: Think about if choose_preimage_var is ok *)
          let%bind h1 = Pedersen.Checked.Digest.choose_preimage h1
          and h2 = Pedersen.Checked.Digest.choose_preimage h2 in
          Pedersen.Checked.digest_triples
            ~init:Hash_prefix.merkle_tree.(height)
            (to_triples h1 @ to_triples h2)

        let assert_equal h1 h2 = Field.Checked.Assert.equal h1 h2

        let if_ = Field.Checked.if_
      end)
      (struct
        include Stack

        type value = t

        let hash = Checked.digest
      end)

  let depth = coinbase_stacks

  include Data_hash.Make_full_size ()

  let merge ~height (h1 : t) (h2 : t) =
    let open Tick.Pedersen in
    State.digest
      (hash_fold
         Hash_prefix.merkle_tree.(height)
         Fold.(Digest.fold (h1 :> field) +> Digest.fold (h2 :> field)))
    |> of_hash

  let empty_hash =
    let open Tick.Pedersen in
    digest_fold
      (State.create params ~get_chunk_table)
      (Fold.string_triples "nothing up my sleeve")
    |> of_hash

  let of_digest = Fn.compose Fn.id of_hash

  type path = Pedersen.Digest.t list

  type _ Request.t +=
    | Stack_path : Index.t -> path Request.t
    | Get_coinbase_stack : Index.t -> (Stack.t * path) Request.t
    | Set_coinbase_stack : Index.t * Stack.t -> unit Request.t
    | Find_index_of_stack : Stack.t -> Index.t Request.t

  let reraise_merkle_requests (With {request; respond}) =
    match request with
    | Merkle_tree.Get_path addr -> respond (Delegate (Stack_path addr))
    | Merkle_tree.Set (addr, stack) ->
        respond (Delegate (Set_coinbase_stack (addr, stack)))
    | Merkle_tree.Get_element addr ->
        respond (Delegate (Get_coinbase_stack addr))
    | _ -> unhandled

  let get t addr =
    handle
      (Merkle_tree.get_req ~depth (var_to_hash_packed t) addr)
      reraise_merkle_requests

  (*
   [modify_stack t pk ~filter ~f] implements the following spec:

   - finds a coinbase stack [stack] in [t] at path [addr] where [filter stack] holds.
     note that the stack is not guaranteed to be in the tree in which case it must
     just have the one coinbase.
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the stack [f stack] at path [addr].
*)
  let%snarkydef modify_stack' t stack
      ~(filter : Stack.var -> ('a, _) Checked.t) ~f =
    let%bind addr =
      request_witness Index.Unpacked.typ
        As_prover.(
          map (read Stack.typ stack) ~f:(fun s -> Find_index_of_stack s))
    in
    handle
      (Merkle_tree.modify_req ~depth (var_to_hash_packed t) addr
         ~f:(fun stack ->
           let%bind x = filter stack in
           f x stack ))
      reraise_merkle_requests
    >>| var_of_hash_packed

  (*
   [edit_stack t pk ~f] implements the following spec:

   - finds a coinbase stack [stack] in [t] at path [addr] OR it doesn't and is a stack with one coinbase
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the stack [f stack] at path [addr].
*)
  let modify_stack t stack ~has_one_coinbase ~f =
    modify_stack' t stack
      ~filter:(fun stack' ->
        let%bind stack_already_there = Stack.Checked.equal stack' stack in
        let%bind stack_not_there =
          Stack.Checked.equal stack' Stack.(var_of_t empty)
        in
        let%bind new_stack = Boolean.(stack_not_there && has_one_coinbase) in
        let%bind () = Boolean.Assert.any [stack_already_there; new_stack] in
        return new_stack )
      ~f:(fun is_empty_and_writeable x -> f ~is_empty_and_writeable x)
end

module T = struct
  module Coinbase_stack = struct
    include Stack

    let hash (t : t) = Hash.of_digest (t :> field)
  end

  include Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Coinbase_stack)
            (Coinbase_stack)

  (*Handler goes here*)
end

include T
