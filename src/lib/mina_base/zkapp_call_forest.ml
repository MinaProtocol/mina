open Core_kernel

type t =
  ( Party.t
  , Parties.Digest.Party.t
  , Parties.Digest.Forest.t )
  Parties.Call_forest.t

type party = (Party.t, Parties.Digest.Party.t) With_hash.t

let empty () = []

let if_ = Parties.value_if

let is_empty = List.is_empty

let pop_exn : t -> (Party.t * t) * t = function
  | { stack_hash = _; elt = { party; calls; party_digest = _ } } :: xs ->
      ((party, calls), xs)
  | _ ->
      failwith "pop_exn"

let push ~party ~calls t = Parties.Call_forest.cons ~calls party t

let hash (t : t) = Parties.Call_forest.hash t

open Snark_params.Tick.Run

module Checked = struct
  module F = Parties.Digest.Forest.Checked
  module V = Prover_value

  type party =
    { party : (Party.Body.Checked.t, Parties.Digest.Party.Checked.t) With_hash.t
    ; control : Control.t Prover_value.t
    }

  let party_typ () :
      (party, (Party.t, Parties.Digest.Party.t) With_hash.t) Typ.t =
    Typ.(Party.Body.typ () * Prover_value.typ () * Parties.Digest.Party.typ)
    |> Typ.transport
         ~back:(fun ((body, authorization), hash) ->
           { With_hash.data = { Party.body; authorization }; hash } )
         ~there:(fun { With_hash.data = { Party.body; authorization }; hash } ->
           ((body, authorization), hash) )
    |> Typ.transport_var
         ~back:(fun ((party, control), hash) ->
           { party = { hash; data = party }; control } )
         ~there:(fun { party = { hash; data = party }; control } ->
           ((party, control), hash) )

  type t =
    ( ( Party.t
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
    with_label "Zkapp_call_forest.pop_exn" (fun () ->
        let hd_r =
          V.create (fun () -> V.get r |> List.hd_exn |> With_stack_hash.elt)
        in
        let party = V.create (fun () -> (V.get hd_r).party) in
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

  let push
      ~party:{ party = { hash = party_hash; data = party }; control = auth }
      ~calls:({ hash = calls_hash; data = calls } : t)
      ({ hash = tl_hash; data = tl_data } : t) : t =
    with_label "Zkapp_call_forest.push" (fun () ->
        let tree_hash =
          Parties.Digest.Tree.Checked.create ~party:party_hash ~calls:calls_hash
        in
        let hash_cons = Parties.Digest.Forest.Checked.cons tree_hash tl_hash in
        let data =
          V.create (fun () ->
              let body = As_prover.read (Party.Body.typ ()) party in
              let authorization = V.get auth in
              let tl = V.get tl_data in
              let party : Party.t = { body; authorization } in
              let calls = V.get calls in
              let res = Parties.Call_forest.cons ~calls party tl in
              (* Sanity check; we're re-hashing anyway, might as well make sure it's
                 consistent.
              *)
              assert (
                Parties.Digest.Forest.(
                  equal
                    (As_prover.read typ hash_cons)
                    (Parties.Call_forest.hash res)) ) ;
              res )
        in
        ({ hash = hash_cons; data } : t) )

  let hash ({ hash; _ } : t) = hash
end

let typ : (Checked.t, t) Typ.t =
  Typ.(Parties.Digest.Forest.typ * Prover_value.typ ())
  |> Typ.transport
       ~back:(fun (_digest, forest) ->
         Parties.Call_forest.map ~f:(fun party -> party) forest )
       ~there:(fun forest ->
         ( Parties.Call_forest.hash forest
         , Parties.Call_forest.map ~f:(fun party -> party) forest ) )
  |> Typ.transport_var
       ~back:(fun (digest, forest) -> { With_hash.hash = digest; data = forest })
       ~there:(fun { With_hash.hash = digest; data = forest } ->
         (digest, forest) )
