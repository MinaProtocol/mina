open Core
open Snark_params
open Snarky
open Tick
open Let_syntax
open Currency

module Merkle_tree = Snarky.Merkle_tree.Checked(Tick)(struct
    open Pedersen.Digest
    include Packed

    let hash h1 h2 =
      (* TODO: Think about if choose_preimage_var is ok *)
      let%bind h1 = choose_preimage_var h1
      and h2 = choose_preimage_var h2
      in
      Tick.hash_digest (Unpacked.var_to_bits h1 @ Unpacked.var_to_bits h2)

    let assert_equal h1 h2 = assert_equal h1 h2

    let if_ = Checked.if_
  end)(Account)

let depth = Snark_params.ledger_depth

module Stable = struct
  module V1 = struct
    type t = Pedersen.Digest.t
    [@@deriving bin_io, sexp]
  end
end

let (=) = Pedersen.Digest.(=)

type var = Pedersen.Digest.Packed.var

let typ = Pedersen.Digest.Packed.typ

let var_to_bits t =
  with_label "Ledger.var_to_bits"
    (Pedersen.Digest.choose_preimage_var t >>| Pedersen.Digest.Unpacked.var_to_bits)

include Pedersen.Digest.Bits

let assert_equal x y = assert_equal x y

include Stable.V1

let of_hash = Fn.id

type path = Pedersen.Digest.t list

type _ Request.t +=
  | Get_path    : Account.Index.t -> path Request.t
  | Get_element : Account.Index.t -> (Account.t * path) Request.t
  | Set         : Account.Index.t * Account.t -> unit Request.t
  | Empty_entry : (Account.Index.t * path) Request.t
  | Find_index  : Public_key.Compressed.t -> Account.Index.t Request.t

let reraise_merkle_requests (With { request; respond }) =
  match request with
  | Merkle_tree.Get_path addr ->
    respond (Reraise (Get_path addr))
  | Merkle_tree.Set (addr, account) ->
    respond (Reraise (Set (addr, account)))
  | Merkle_tree.Get_element addr ->
    respond (Reraise (Get_element addr))
  | _ -> unhandled

(* 
   [modify_account t pk ~f] implements the following spec:

   - finds an account [account] in [t] at path [addr] whose public key is [pk]
   - returns a root [t'] of a tree of depth [depth]
   which is [t] but with the account [f account] at path [addr].
*)
let modify_account t pk ~f =
  let%bind addr =
    request_witness Account.Index.Unpacked.typ
      As_prover.(
        map (read Public_key.Compressed.typ pk)
          ~f:(fun s -> Find_index s))
  in
  handle
    (Merkle_tree.modify_req ~depth t addr ~f:(fun account ->
      let%bind () = Public_key.Compressed.assert_equal account.public_key pk in
      f account))
    reraise_merkle_requests

(* [create_account t pk] implements the following spec:

   - finds an address [addr] such that the account at path [addr] in [t] has
   the same hash as [Account.empty_hash]
   - returns the merkle tree [t'] which is [t] but with the account
   [{ public_key = pk; balance = Account.Balance.zero }] at [addr] instead of
   an account with the empty hash
*)
let create_account t pk =
  let%bind addr, path =
    request Typ.(Account.Index.Unpacked.typ * Merkle_tree.Path.typ ~depth)
      Empty_entry
  in
  let%bind () =
    Merkle_tree.implied_root
      (Cvar.constant Account.empty_hash) (* Could save some boolean constraints by unpacking this outside the snark *)
      addr
      path
    >>= assert_equal t
  in
  let account : Account.var = { public_key = pk; balance = Balance.(var_of_t zero) } in
  (* Could save some constraints applying Account.Balance.zero to the hash
     (since it's a no-op) *)
  let%bind account_hash = Account.hash account in
  let%bind () =
    perform As_prover.(Let_syntax.(
      let%map addr = read Account.Index.Unpacked.typ addr
      and account = read Account.typ account
      in
      Set (addr, account)))
  in
  Merkle_tree.implied_root account_hash addr path

