open Core_kernel
open Module_version

module Input = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = {descendant: State_hash.Stable.V1.t; generations: int}
        [@@deriving sexp, bin_io]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "ancestor"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest
end

module Output = State_hash

module Proof = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = State_body_hash.Stable.V1.t list [@@deriving bin_io]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "ancestor_proof"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest
end

let verify =
  let rec go acc = function
    | [] -> acc
    | h :: hs ->
        let acc =
          Protocol_state.hash ~hash_body:Fn.id
            {previous_state_hash= acc; body= h}
        in
        go acc hs
  in
  fun ({descendant; generations} : Input.t) (ancestor : Output.t)
      (proof : Proof.t) ->
    List.length proof = generations
    && State_hash.equal descendant (go ancestor proof)

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

  val verify_and_add :
       t
    -> Input.t
    -> Output.t
    -> ancestor_length:Coda_numbers.Length.t
    -> Proof.t
    -> unit Or_error.t

  val prove : t -> Input.t -> (Output.t * Proof.t) option
end = struct
  module T = Linked_tree.Make (State_hash)

  type t = State_body_hash.t T.t

  let create = T.create

  let add t ~prev_hash ~hash ~length ~body_hash =
    ignore (T.add t ~prev_key:prev_hash ~key:hash ~length ~data:body_hash)

  let check cond err = if cond then Ok () else Or_error.error_string err

  let verify_and_add =
    let rec go hs acc length = function
      | [] -> (acc, List.rev hs)
      | body :: bs ->
          let length = Coda_numbers.Length.succ length in
          let full_state_hash =
            Protocol_state.hash ~hash_body:Fn.id
              {previous_state_hash= acc; body}
          in
          go
            ((acc, full_state_hash, length, body) :: hs)
            full_state_hash length bs
    in
    fun (t : t) ({descendant; generations} : Input.t) (ancestor : Output.t)
        ~ancestor_length (proof : Proof.t) ->
      let open Or_error.Let_syntax in
      let%bind () =
        check (List.length proof = generations) "Wrong proof length"
      in
      let h, to_add = go [] ancestor ancestor_length proof in
      let%map () = check (State_hash.equal h descendant) "Bad merkle proof" in
      List.iter to_add ~f:(fun (prev, h, length, body) ->
          add t ~prev_hash:prev ~hash:h ~length ~body_hash:body )

  let prove (t : t) {Input.descendant; generations} :
      (Output.t * Proof.t) option =
    T.ancestor_of_depth t ~depth:generations ~source:descendant
end

let%test_unit "completeness" =
  let open Coda_numbers in
  let open Quickcheck in
  let open Generator in
  let ancestor = State_hash.gen in
  let bodies = list State_body_hash.gen in
  test (tuple2 ancestor bodies) ~trials:300 ~f:(fun (ancestor, bs) ->
      let n = List.length bs in
      let prover = Prover.create ~max_size:(2 * n) in
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
      List.iteri hashes ~f:(fun i h ->
          let input = {Input.generations= i + 1; descendant= h} in
          let a, proof =
            Prover.prove prover {generations= i + 1; descendant= h}
            |> Option.value_exn ?here:None ?error:None ?message:None
          in
          [%test_eq: State_hash.t] a ancestor ;
          assert (verify input a proof) ) )
