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
      type value = Field.t

      type var = Field.Var.t

      let typ = Field.typ

      let merge ~height h1 h2 =
        Tick.make_checked (fun () ->
            Random_oracle.Checked.hash
              ~init:Hash_prefix.Random_oracle.merkle_tree.(height)
              [|h1; h2|] )

      let assert_equal h1 h2 = Field.Checked.Assert.equal h1 h2

      let if_ = Field.Checked.if_
    end)
    (struct
      include Account

      let hash = Checked.digest
    end)

let depth = Snark_params.ledger_depth

include Data_hash.Make_full_size ()

module T = struct
  type t = Stable.Latest.t [@@deriving bin_io]

  let description = "Ledger hash"

  let version_byte = Base58_check.Version_bytes.ledger_hash
end

module Base58_check = Codable.Make_base58_check (T)

let to_string t = Base58_check.String_ops.to_string t

let of_string s = Base58_check.String_ops.of_string s

let merge ~height (h1 : t) (h2 : t) =
  Random_oracle.hash
    ~init:Hash_prefix.Random_oracle.merkle_tree.(height)
    [|(h1 :> field); (h2 :> field)|]
  |> of_hash

(* TODO: @ihm cryptography review *)
let empty_hash =
  let open Tick.Pedersen in
  digest_fold (State.create ()) (Fold.string_triples "nothing up my sleeve")
  |> of_hash

let of_digest = Fn.compose Fn.id of_hash

type path = Pedersen.Digest.t list

type _ Request.t +=
  | Get_path : Account.Index.t -> path Request.t
  | Get_element : Account.Index.t -> (Account.t * path) Request.t
  | Set : Account.Index.t * Account.t -> unit Request.t
  | Find_index : Public_key.Compressed.t -> Account.Index.t Request.t

let reraise_merkle_requests (With {request; respond}) =
  match request with
  | Merkle_tree.Get_path addr ->
      respond (Delegate (Get_path addr))
  | Merkle_tree.Set (addr, account) ->
      respond (Delegate (Set (addr, account)))
  | Merkle_tree.Get_element addr ->
      respond (Delegate (Get_element addr))
  | _ ->
      unhandled

let get t addr =
  handle
    (Merkle_tree.get_req ~depth (var_to_hash_packed t) addr)
    reraise_merkle_requests

(*
   [modify_account t pk ~filter ~f] implements the following spec:

   - finds an account [account] in [t] for [pk] at path [addr] where [filter account] holds.
     note that the account is not guaranteed to have public key [pk]; it might be a new account
     created to satisfy this request.
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the account [f account] at path [addr].
*)
let%snarkydef modify_account t pk ~(filter : Account.var -> ('a, _) Checked.t)
    ~f =
  let%bind addr =
    request_witness Account.Index.Unpacked.typ
      As_prover.(
        map (read Public_key.Compressed.typ pk) ~f:(fun s -> Find_index s))
  in
  handle
    (Merkle_tree.modify_req ~depth (var_to_hash_packed t) addr
       ~f:(fun account ->
         let%bind x = filter account in
         f x account ))
    reraise_merkle_requests
  >>| var_of_hash_packed

(*
   [modify_account_send t pk ~f] implements the following spec:

   - finds an account [account] in [t] at path [addr] whose public key is [pk] OR it is a fee transfer and is an empty account
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the account [f account] at path [addr].
*)
let%snarkydef modify_account_send t pk ~is_writeable ~f =
  modify_account t pk
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
   [modify_account_recv t ~pk ~f] implements the following spec:

   - finds an account [account] in [t] at path [addr] whose public key is [pk] OR which is an empty account
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the account [f account] at path [addr].
*)
let%snarkydef modify_account_recv t pk ~f =
  modify_account t pk
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
