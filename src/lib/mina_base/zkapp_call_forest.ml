open Core_kernel

(* Same as the type of the field account_updates in Mina_base.Zkapp_command.t *)
type t =
  ( Account_update.t
  , Zkapp_command.Digest.Account_update.t
  , Zkapp_command.Digest.Forest.t )
  Zkapp_command.Call_forest.t

type account_update =
  (Account_update.t, Zkapp_command.Digest.Account_update.t) With_hash.t

let empty () = []

let if_ = Zkapp_command.value_if

let is_empty = List.is_empty

let pop_exn : t -> (Account_update.t * t) * t = function
  | { stack_hash = _
    ; elt = { account_update; calls; account_update_digest = _ }
    }
    :: xs ->
      ((account_update, calls), xs)
  | _ ->
      failwith "pop_exn"

let push ~account_update ~calls t =
  Zkapp_command.Call_forest.cons ~calls account_update t

let hash (t : t) = Zkapp_command.Call_forest.hash t

open Snark_params.Tick.Run

module Checked = struct
  module F = Zkapp_command.Digest.Forest.Checked
  module V = Prover_value

  type account_update =
    { account_update :
        ( Account_update.Body.Checked.t
        , Zkapp_command.Digest.Account_update.Checked.t )
        With_hash.t
    ; control : Control.t Prover_value.t
    }

  let account_update_typ () :
      ( account_update
      , (Account_update.t, Zkapp_command.Digest.Account_update.t) With_hash.t
      )
      Typ.t =
    let (Typ typ) =
      Typ.(
        Account_update.Body.typ () * Prover_value.typ ()
        * Zkapp_command.Digest.Account_update.typ)
      |> Typ.transport
           ~back:(fun ((body, authorization), hash) ->
             { With_hash.data = { Account_update.body; authorization }; hash }
             )
           ~there:(fun { With_hash.data = { Account_update.body; authorization }
                       ; hash
                       } -> ((body, authorization), hash) )
      |> Typ.transport_var
           ~back:(fun ((account_update, control), hash) ->
             { account_update = { hash; data = account_update }; control } )
           ~there:(fun { account_update = { hash; data = account_update }
                       ; control
                       } -> ((account_update, control), hash) )
    in
    Typ
      { typ with
        check =
          (fun ( { account_update = { hash; data = account_update }
                 ; control = _
                 } as x ) ->
            Impl.make_checked (fun () ->
                Impl.run_checked (typ.check x) ;
                Field.Assert.equal
                  (hash :> Field.t)
                  ( Zkapp_command.Call_forest.Digest.Account_update.Checked
                    .create account_update
                    :> Field.t ) ) )
      }

  type t =
    ( ( Account_update.t
      , Zkapp_command.Digest.Account_update.t
      , Zkapp_command.Digest.Forest.t )
      Zkapp_command.Call_forest.t
      V.t
    , F.t )
    With_hash.t

  let if_ b ~then_:(t : t) ~else_:(e : t) : t =
    { hash = F.if_ b ~then_:t.hash ~else_:e.hash
    ; data = V.if_ b ~then_:t.data ~else_:e.data
    }

  let empty =
    Zkapp_command.Digest.Forest.constant
      Zkapp_command.Call_forest.With_hashes.empty

  let is_empty ({ hash = x; _ } : t) = F.equal empty x

  let empty () : t = { hash = empty; data = V.create (fun () -> []) }

  let pop_exn ({ hash = h; data = r } : t) : (account_update * t) * t =
    with_label "Zkapp_call_forest.pop_exn" (fun () ->
        let hd_r =
          V.create (fun () -> V.get r |> List.hd_exn |> With_stack_hash.elt)
        in
        let account_update = V.create (fun () -> (V.get hd_r).account_update) in
        let auth =
          V.(create (fun () -> (V.get account_update).authorization))
        in
        let account_update =
          exists (Account_update.Body.typ ()) ~compute:(fun () ->
              (V.get account_update).body )
        in
        let account_update =
          With_hash.of_data account_update
            ~hash_data:Zkapp_command.Digest.Account_update.Checked.create
        in
        let subforest : t =
          let subforest = V.create (fun () -> (V.get hd_r).calls) in
          let subforest_hash =
            exists Zkapp_command.Digest.Forest.typ ~compute:(fun () ->
                Zkapp_command.Call_forest.hash (V.get subforest) )
          in
          { hash = subforest_hash; data = subforest }
        in
        let tl_hash =
          exists Zkapp_command.Digest.Forest.typ ~compute:(fun () ->
              V.get r |> List.tl_exn |> Zkapp_command.Call_forest.hash )
        in
        let tree_hash =
          Zkapp_command.Digest.Tree.Checked.create
            ~account_update:account_update.hash ~calls:subforest.hash
        in
        let hash_cons =
          Zkapp_command.Digest.Forest.Checked.cons tree_hash tl_hash
        in
        F.Assert.equal hash_cons h ;
        ( ( ({ account_update; control = auth }, subforest)
          , { hash = tl_hash
            ; data = V.(create (fun () -> List.tl_exn (get r)))
            } )
          : (account_update * t) * t ) )

  let push
      ~account_update:
        { account_update = { hash = account_update_hash; data = account_update }
        ; control = auth
        } ~calls:({ hash = calls_hash; data = calls } : t)
      ({ hash = tl_hash; data = tl_data } : t) : t =
    with_label "Zkapp_call_forest.push" (fun () ->
        let tree_hash =
          Zkapp_command.Digest.Tree.Checked.create
            ~account_update:account_update_hash ~calls:calls_hash
        in
        let hash_cons =
          Zkapp_command.Digest.Forest.Checked.cons tree_hash tl_hash
        in
        let data =
          V.create (fun () ->
              let body =
                As_prover.read (Account_update.Body.typ ()) account_update
              in
              let authorization = V.get auth in
              let tl = V.get tl_data in
              let account_update : Account_update.t = { body; authorization } in
              let calls = V.get calls in
              let res =
                Zkapp_command.Call_forest.cons ~calls account_update tl
              in
              (* Sanity check; we're re-hashing anyway, might as well make sure it's
                 consistent.
              *)
              assert (
                Zkapp_command.Digest.Forest.(
                  equal
                    (As_prover.read typ hash_cons)
                    (Zkapp_command.Call_forest.hash res)) ) ;
              res )
        in
        ({ hash = hash_cons; data } : t) )

  let hash ({ hash; _ } : t) = hash
end

let typ : (Checked.t, t) Typ.t =
  Typ.(Zkapp_command.Digest.Forest.typ * Prover_value.typ ())
  |> Typ.transport
       ~back:(fun (_digest, forest) ->
         Zkapp_command.Call_forest.map
           ~f:(fun account_update -> account_update)
           forest )
       ~there:(fun forest ->
         ( Zkapp_command.Call_forest.hash forest
         , Zkapp_command.Call_forest.map
             ~f:(fun account_update -> account_update)
             forest ) )
  |> Typ.transport_var
       ~back:(fun (digest, forest) -> { With_hash.hash = digest; data = forest })
       ~there:(fun { With_hash.hash = digest; data = forest } ->
         (digest, forest) )
