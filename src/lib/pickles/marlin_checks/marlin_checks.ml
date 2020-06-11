open Core_kernel
open Pickles_types
module Domain = Domain

type 'field domain = < size: 'field ; vanishing_polynomial: 'field -> 'field >

let debug = false

module type Field_intf = sig
  type t

  val one : t

  val of_int : int -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val ( + ) : t -> t -> t

  val ( - ) : t -> t -> t
end

type 'f field = (module Field_intf with type t = 'f)

let map_reduce reduce xs map = List.reduce_exn (List.map xs ~f:map) ~f:reduce

(* x^{2 ^ k} - 1 *)
let vanishing_polynomial (type t) ((module F) : t field) domain x =
  let k = Domain.log2_size domain in
  let rec pow2pow acc i =
    if i = 0 then acc else pow2pow F.(acc * acc) (i - 1)
  in
  F.(pow2pow x k - one)

let domain (type t) ((module F) : t field) (domain : Domain.t) : t domain =
  let size = F.of_int (Domain.size domain) in
  object
    method size = size

    method vanishing_polynomial x = vanishing_polynomial (module F) domain x
  end

let all_but m = List.filter Abc.Label.all ~f:(( <> ) m)
