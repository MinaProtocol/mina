open Core_kernel

type t =
  ( Party.t
  , Parties.Digest.Party.t
  , Parties.Digest.Forest.t )
  Parties.Call_forest.t

let empty () = []

let if_ = Parties.value_if

let is_empty = List.is_empty

let pop_exn : t -> (Party.t * t) * t = function
  | { stack_hash = _; elt = { party; calls; party_digest = _ } } :: xs ->
      ((party, calls), xs)
  | _ ->
      failwith "pop_exn"

module Checked = struct
  open Snark_params.Tick.Run
  module F = Parties.Digest.Forest.Checked
  module V = Prover_value

  type party =
    { party : (Party.Body.Checked.t, Parties.Digest.Party.Checked.t) With_hash.t
    ; control : Control.t Prover_value.t
    }

  type t =
    ( ( Party.t * unit
      , Parties.Digest.Party.t
      , Parties.Digest.Forest.t )
      Parties.Call_forest.t
      V.t
    , F.t )
    With_hash.t

  let if_ b ~then_:(t : t) ~else_:(e : t) : t =
    { hash = F.if_ b ~then_:t.hash ~else_:e.hash
    ; data = V.if_ b ~then_:t.data ~else_:e.data
    }

  let empty =
    Parties.Digest.Forest.constant Parties.Call_forest.With_hashes.empty

  let is_empty ({ hash = x; _ } : t) = F.equal empty x

  let empty () : t = { hash = empty; data = V.create (fun () -> []) }

  let pop_exn ({ hash = h; data = r } : t) : (party * t) * t =
    with_label "Parties.pop_exn" (fun () ->
        let hd_r =
          V.create (fun () -> V.get r |> List.hd_exn |> With_stack_hash.elt)
        in
        let party = V.create (fun () -> (V.get hd_r).party |> fst) in
        let auth = V.(create (fun () -> (V.get party).authorization)) in
        let party =
          exists (Party.Body.typ ()) ~compute:(fun () -> (V.get party).body)
        in
        let party =
          With_hash.of_data party ~hash_data:Parties.Digest.Party.Checked.create
        in
        let subforest : t =
          let subforest = V.create (fun () -> (V.get hd_r).calls) in
          let subforest_hash =
            exists Parties.Digest.Forest.typ ~compute:(fun () ->
                Parties.Call_forest.hash (V.get subforest) )
          in
          { hash = subforest_hash; data = subforest }
        in
        let tl_hash =
          exists Parties.Digest.Forest.typ ~compute:(fun () ->
              V.get r |> List.tl_exn |> Parties.Call_forest.hash )
        in
        let tree_hash =
          Parties.Digest.Tree.Checked.create ~party:party.hash
            ~calls:subforest.hash
        in
        let hash_cons = Parties.Digest.Forest.Checked.cons tree_hash tl_hash in
        F.Assert.equal hash_cons h ;
        ( ( ({ party; control = auth }, subforest)
          , { hash = tl_hash
            ; data = V.(create (fun () -> List.tl_exn (get r)))
            } )
          : (party * t) * t ) )
end
