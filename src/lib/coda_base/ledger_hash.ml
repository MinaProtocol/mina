open Core
open Import
open Snark_params
open Snarky
open Tick
open Let_syntax
open Fold_lib

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
      include Account

      let hash = Checked.digest
    end)

let depth = Snark_params.ledger_depth

include Data_hash.Make_full_size ()

let merge ~height (h1 : t) (h2 : t) =
  let open Tick.Pedersen in
  State.digest
    (hash_fold
       Hash_prefix.merkle_tree.(height)
       Fold.(Digest.fold (h1 :> field) +> Digest.fold (h2 :> field)))
  |> of_hash

(* TODO: @ihm cryptography review *)
let empty_hash =
  let open Tick.Pedersen in
  digest_fold (State.create ()) (Fold.string_triples "nothing up my sleeve")
  |> of_hash

let of_digest = Fn.compose Fn.id of_hash

type path = Pedersen.Digest.t list

module Tag0 = struct
  type t = Curr_ledger | Epoch_ledger [@@deriving eq, enum]
end

module Tag = struct
  include Tag0
  include Enumerable (Tag0)

  let curr_ledger = var Curr_ledger

  let epoch_ledger = var Epoch_ledger
end

type _ Request.t +=
  | Get_path : Tag.t * Account.Index.t -> path Request.t
  | Get_element : Tag.t * Account.Index.t -> (Account.t * path) Request.t
  | Set : Tag.t * Account.Index.t * Account.t -> unit Request.t
  | Find_index : Tag.t * Public_key.Compressed.t -> Account.Index.t Request.t

let reraise_merkle_requests ~tag (With {request; respond}) =
  match request with
  | Merkle_tree.Get_path addr ->
      respond (Delegate (Get_path (tag, addr)))
  | Merkle_tree.Set (addr, account) ->
      respond (Delegate (Set (tag, addr, account)))
  | Merkle_tree.Get_element addr ->
      respond (Delegate (Get_element (tag, addr)))
  | _ ->
      unhandled

let get ~tag t addr =
  handle_as_prover
    (Merkle_tree.get_req ~depth (var_to_hash_packed t) addr)
    As_prover.(read Tag.typ tag >>| fun tag -> reraise_merkle_requests ~tag)

(*
   [fetch_and_update_account ~tag t pk ~filter ~f] implements the following spec:

   - finds an account [account] in [t] for [pk] at path [addr] where [filter account] holds.
     note that the account is not guaranteed to have public key [pk]; it might be a new account
     created to satisfy this request.
   - returns a root [t'] of a tree of depth [depth] and the old [account]
   which is [t] but with the account [f account] at path [addr].
*)
let%snarkydef fetch_and_update_account ~tag t pk
    ~(filter : Account.var -> ('a, _) Checked.t) ~f =
  let%bind addr =
    request_witness Account.Index.Unpacked.typ
      As_prover.(
        let%map tag = read Tag.typ tag
        and pk = read Public_key.Compressed.typ pk in
        Find_index (tag, pk))
  in
  let%map new_root, account =
    handle_as_prover
      (Merkle_tree.fetch_and_update_req ~depth (var_to_hash_packed t) addr
         ~f:(fun account ->
           let%bind x = filter account in
           f x account ))
      As_prover.(
        let%map tag = read Tag.typ tag in
        reraise_merkle_requests ~tag)
  in
  (var_of_hash_packed new_root, account)

let%snarkydef modify_account ~tag t pk
    ~(filter : Account.var -> ('a, _) Checked.t) ~f =
  fetch_and_update_account ~tag t pk ~filter ~f >>| fst

(*
   [modify_account_send ~tag t pk ~f] implements the following spec:

   - finds an account [account] in [t] at path [addr] whose public key is [pk] OR it is a fee transfer and is an empty account
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the account [f account] at path [addr].
*)
let%snarkydef modify_account_send ~tag t pk ~is_writeable ~f =
  modify_account ~tag t pk
    ~filter:(fun account ->
      let%bind account_already_there =
        Public_key.Compressed.Checked.equal account.public_key pk
      in
      let%bind account_not_there =
        Public_key.Compressed.Checked.equal account.public_key
          Public_key.Compressed.(var_of_t empty)
      in
      let%bind not_there_but_writeable =
        Boolean.(account_not_there && is_writeable)
      in
      let%bind () =
        Boolean.Assert.any [account_already_there; not_there_but_writeable]
      in
      return not_there_but_writeable )
    ~f:(fun is_empty_and_writeable x -> f ~is_empty_and_writeable x)

(*
   [modify_account_recv ~tag t ~pk ~f] implements the following spec:

   - finds an account [account] in [t] at path [addr] whose public key is [pk] OR which is an empty account
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the account [f account] at path [addr].
*)
let%snarkydef modify_account_recv ~tag t pk ~f =
  modify_account ~tag t pk
    ~filter:(fun account ->
      let%bind account_already_there =
        Public_key.Compressed.Checked.equal account.public_key pk
      in
      let%bind account_not_there =
        Public_key.Compressed.Checked.equal account.public_key
          Public_key.Compressed.(var_of_t empty)
      in
      let%bind () =
        Boolean.Assert.any [account_already_there; account_not_there]
      in
      return account_not_there )
    ~f:(fun is_empty_and_writeable x -> f ~is_empty_and_writeable x)
