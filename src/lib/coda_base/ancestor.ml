open Core_kernel

module Stable = struct
  module V1 = struct
    type t = State_body_hash.Stable.V1.t list [@@deriving bin_io]
  end
end

include Stable.V1

type proof = t

let verify (proof : t) ~ancestor ~descendant =
  let rec go acc = function
    | [] -> acc
    | h :: hs ->
        let acc =
          Protocol_state.hash ~hash_body:Fn.id
            {previous_state_hash= acc; body= h}
        in
        go acc hs
  in
  State_hash.equal descendant (go ancestor proof)

module Prover : sig
  type t

  val create : max_size:int -> t

  val add :
       t
    -> prev_hash:State_hash.t
    -> hash:State_hash.t
    -> length:Coda_numbers.Length.t
    -> body_hash:State_body_hash.t
    -> unit

  val prove : t -> source:State_hash.t -> ancestor:State_hash.t -> proof option
end = struct
  module T = Linked_tree.Make (State_hash)

  type t = State_body_hash.t T.t

  let create = T.create

  let add t ~prev_hash ~hash ~length ~body_hash =
    ignore (T.add t ~prev_key:prev_hash ~key:hash ~length ~data:body_hash)

  let prove (t : t) ~source ~ancestor = T.path t ~source ~ancestor
end

let%test_unit "completeness" =
  let open Coda_numbers in
  let open Quickcheck in
  let open Generator in
  let ancestor = State_hash.gen in
  let bodies = list State_body_hash.gen in
  test (tuple2 ancestor bodies) ~f:(fun (ancestor, bs) ->
      let prover = Prover.create ~max_size:(2 * List.length bs) in
      let hashes =
        List.folding_map bs ~init:(ancestor, Length.zero)
          ~f:(fun (prev, length) body ->
            let length = Length.succ length in
            let h =
              Protocol_state.hash ~hash_body:Fn.id
                {previous_state_hash= prev; body}
            in
            Prover.add prover ~prev_hash:prev ~hash:h ~length ~body_hash:body ;
            ((h, length), h) )
      in
      List.iter hashes ~f:(fun h ->
          assert (
            verify
              (Option.value_exn (Prover.prove prover ~source:h ~ancestor))
              ~ancestor ~descendant:h ) ) )
