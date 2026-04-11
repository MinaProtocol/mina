open Core_kernel
open Mina_base

module Input = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { descendant : State_hash.Stable.V1.t; generations : int }
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]
end

module Output = State_hash

module Proof = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = State_body_hash.Stable.V1.t list

      let to_latest = Fn.id
    end
  end]
end

let verify =
  let rec go acc = function
    | [] ->
        acc
    | h :: hs ->
        let acc =
          Protocol_state.hashes_abstract ~hash_body:Fn.id
            { previous_state_hash = acc; body = h }
        in
        go acc.state_hash hs
  in
  fun ({ descendant; generations } : Input.t) (ancestor : Output.t)
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
    -> length:Mina_numbers.Length.t
    -> body_hash:State_body_hash.t
    -> unit

  val verify_and_add :
       t
    -> Input.t
    -> Output.t
    -> ancestor_length:Mina_numbers.Length.t
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
      | [] ->
          (acc, List.rev hs)
      | body :: bs ->
          let length = Mina_numbers.Length.succ length in
          let full_state_hashes =
            Protocol_state.hashes_abstract ~hash_body:Fn.id
              { previous_state_hash = acc; body }
          in
          go
            ((acc, full_state_hashes.state_hash, length, body) :: hs)
            full_state_hashes.state_hash length bs
    in
    fun (t : t) ({ descendant; generations } : Input.t) (ancestor : Output.t)
        ~ancestor_length (proof : Proof.t) ->
      let open Or_error.Let_syntax in
      let%bind () =
        check (List.length proof = generations) "Wrong proof length"
      in
      let h, to_add = go [] ancestor ancestor_length proof in
      let%map () = check (State_hash.equal h descendant) "Bad merkle proof" in
      List.iter to_add ~f:(fun (prev, h, length, body) ->
          add t ~prev_hash:prev ~hash:h ~length ~body_hash:body )

  let prove (t : t) { Input.descendant; generations } :
      (Output.t * Proof.t) option =
    T.ancestor_of_depth t ~depth:generations ~source:descendant
end

let%test_unit "completeness" =
  let open Mina_numbers in
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
            let hs =
              Protocol_state.hashes_abstract ~hash_body:Fn.id
                { previous_state_hash = prev; body }
            in
            Prover.add prover ~prev_hash:prev ~hash:hs.state_hash ~length
              ~body_hash:body ;
            ((hs.state_hash, length), hs.state_hash) )
      in
      List.iteri hashes ~f:(fun i h ->
          let input = { Input.generations = i + 1; descendant = h } in
          let a, proof =
            Prover.prove prover { generations = i + 1; descendant = h }
            |> Option.value_exn ?here:None ?error:None ?message:None
          in
          [%test_eq: State_hash.t] a ancestor ;
          assert (verify input a proof) ) )

let%test_unit "verify rejects wrong ancestor" =
  let open Quickcheck in
  test
    (Generator.tuple3 State_hash.gen State_hash.gen
       (Generator.list State_body_hash.gen) )
    ~trials:100
    ~f:(fun (ancestor, wrong_ancestor, bs) ->
      if State_hash.equal ancestor wrong_ancestor then ()
      else
        let n = List.length bs in
        if n = 0 then ()
        else
          let prover = Prover.create ~max_size:(2 * n) in
          let hashes =
            List.folding_map bs ~init:(ancestor, Mina_numbers.Length.zero)
              ~f:(fun (prev, length) body ->
                let length = Mina_numbers.Length.succ length in
                let hs =
                  Protocol_state.hashes_abstract ~hash_body:Fn.id
                    { previous_state_hash = prev; body }
                in
                Prover.add prover ~prev_hash:prev ~hash:hs.state_hash ~length
                  ~body_hash:body ;
                ((hs.state_hash, length), hs.state_hash) )
          in
          let descendant = List.last_exn hashes in
          let input = { Input.generations = List.length hashes; descendant } in
          let _, proof =
            Prover.prove prover input
            |> Option.value_exn ?here:None ?error:None ?message:None
          in
          assert (not (verify input wrong_ancestor proof)) )

let%test_unit "verify rejects wrong proof length" =
  let open Quickcheck in
  test
    (Generator.tuple2 State_hash.gen
       (Generator.list_non_empty State_body_hash.gen) )
    ~trials:100
    ~f:(fun (ancestor, bs) ->
      let n = List.length bs in
      let prover = Prover.create ~max_size:(2 * n) in
      let hashes =
        List.folding_map bs ~init:(ancestor, Mina_numbers.Length.zero)
          ~f:(fun (prev, length) body ->
            let length = Mina_numbers.Length.succ length in
            let hs =
              Protocol_state.hashes_abstract ~hash_body:Fn.id
                { previous_state_hash = prev; body }
            in
            Prover.add prover ~prev_hash:prev ~hash:hs.state_hash ~length
              ~body_hash:body ;
            ((hs.state_hash, length), hs.state_hash) )
      in
      let descendant = List.last_exn hashes in
      (* ask for more generations than the proof actually has *)
      let wrong_input =
        { Input.generations = List.length hashes + 1; descendant }
      in
      match Prover.prove prover wrong_input with
      | None ->
          () (* prover correctly can't produce proof *)
      | Some (a, proof) ->
          (* if it did produce something, verify should fail *)
          assert (not (verify wrong_input a proof)) )

let%test_unit "verify_and_add rejects bad proof" =
  let open Quickcheck in
  test (Generator.tuple3 State_hash.gen State_body_hash.gen State_body_hash.gen)
    ~trials:100 ~f:(fun (ancestor, body1, wrong_body) ->
      if State_body_hash.equal body1 wrong_body then ()
      else
        let prover = Prover.create ~max_size:10 in
        let hs =
          Protocol_state.hashes_abstract ~hash_body:Fn.id
            { previous_state_hash = ancestor; body = body1 }
        in
        Prover.add prover ~prev_hash:ancestor ~hash:hs.state_hash
          ~length:Mina_numbers.Length.(succ zero)
          ~body_hash:body1 ;
        let input = { Input.generations = 1; descendant = hs.state_hash } in
        (* use wrong body in proof *)
        let result =
          Prover.verify_and_add prover input ancestor
            ~ancestor_length:Mina_numbers.Length.zero [ wrong_body ]
        in
        assert (Or_error.is_error result) )
