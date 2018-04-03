open Core
open Snark_params
open Tick
open Let_syntax
open Currency

module Index = struct
  type t = int

  module Vector = struct
    include Int
    let length = Snark_params.ledger_depth
    let empty = zero
    let get t i = (t lsr i) land 1 = 1
    let set v i b =
      if b
      then v lor (one lsl i)
      else v land (lnot (one lsl i))
  end

  include (Bits.Vector.Make(Vector) : Bits_intf.S with type t := t)
  include Bits.Snarkable.Small_bit_vector(Tick)(Vector)
end

type ('pk, 'amount) t_ =
  { public_key : 'pk
  ; balance : 'amount
  }
[@@deriving sexp]

type var = (Public_key.Compressed.var, Balance.var) t_
type value = (Public_key.Compressed.t, Balance.t) t_
[@@deriving sexp]
type t = value
[@@deriving sexp]

let empty_hash =
  Pedersen.hash_bigstring (Bigstring.of_string "nothing up my sleeve")

let typ : (var, value) Typ.t =
  let spec =
    Data_spec.(
      [ Public_key.Compressed.typ; Balance.typ ])
  in
  let of_hlist : 'a 'b. (unit, 'a -> 'b -> unit) H_list.t -> ('a, 'b) t_ =
    H_list.(fun [ public_key; balance ] -> { public_key; balance })
  in
  let to_hlist { public_key; balance } = H_list.([ public_key; balance ]) in
  Typ.of_hlistable spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_bits { public_key; balance } =
  let%map public_key = Public_key.Compressed.var_to_bits public_key in
  let balance = Balance.var_to_bits balance in
  public_key @ balance

let fold_bits ({ public_key; balance } : t) =
  fun ~init ~f ->
    let init = Public_key.Compressed.fold public_key ~init ~f in
    Balance.fold balance ~init ~f

let hash t =
  var_to_bits t
  >>= hash_digest

