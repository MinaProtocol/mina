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

type var =
  { digest       : Pedersen.Digest.Packed.var
  ; mutable bits : Boolean.var Bitstring.Lsb_first.t option
  }

let var_to_bits t =
  with_label "Ledger.var_to_bits" begin
    match t.bits with
    | Some bits ->
      return (bits :> Boolean.var list)
    | None ->
      let%map bits =
        Pedersen.Digest.choose_preimage_var t.digest
        >>| Pedersen.Digest.Unpacked.var_to_bits
      in
      t.bits <- Some (Bitstring.Lsb_first.of_list bits);
      bits
  end

include Pedersen.Digest.Bits

include Stable.V1

let typ : (var, t) Typ.t =
  let store (t : t) =
    let open Typ.Store.Let_syntax in
    let n = Bigint.of_field t in
    let rec go i acc =
      if i < 0
      then return (Bitstring.Lsb_first.of_list acc)
      else
        let%bind b = Boolean.typ.store (Bigint.test_bit n i) in
        go (i - 1) (b :: acc)
    in
    let%map bits = go (Field.size_in_bits - 1) [] in
    { bits = Some bits
    ; digest = Checked.project (bits :> Boolean.var list)
    }
  in
  let read (t : var) = Field.typ.read t.digest in
  let bitstring = Typ.list ~length:Field.size_in_bits Boolean.typ in
  let alloc =
    Typ.Alloc.map bitstring.alloc ~f:(fun bits ->
      { digest = Checked.project bits
      ; bits = Some (Bitstring.Lsb_first.of_list bits)
      })
  in
  let check { bits; _ } = bitstring.check (Option.value_exn bits :> Boolean.var list) in
  { store
  ; read
  ; alloc
  ; check
  }

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

let of_digest digest = { digest; bits = None }

let modify_account t pk ~f =
  let%bind addr =
    request_witness Account.Index.Unpacked.typ
      As_prover.(
        map (read Public_key.Compressed.typ pk)
          ~f:(fun s -> Find_index s))
  in
  handle
    (Merkle_tree.modify_req ~depth t.digest addr ~f:(fun account ->
      let%bind () = Public_key.Compressed.assert_equal account.public_key pk in
      f account))
    reraise_merkle_requests
  >>| of_digest

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
    >>= assert_equal t.digest
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
  >>| of_digest

let assert_equal x y = assert_equal x.digest y.digest

