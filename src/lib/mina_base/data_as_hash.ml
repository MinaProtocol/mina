open Snark_params
open Tick

type 'a t = Field.Var.t * 'a Typ.prover_value

let hash (x, _) = x

let prover_value (_, x) = x

let typ ~hash =
  Typ.transport
    Typ.(Field.typ * prover_value ())
    ~there:(fun s -> (hash s, s))
    ~back:(fun (_, s) -> s)

let optional_typ ~hash ~non_preimage ~dummy_value =
  Typ.transport
    Typ.(Field.typ * prover_value ())
    ~there:(function
      | None -> (non_preimage, dummy_value) | Some s -> (hash s, s) )
    ~back:(fun (_, s) -> Some s)

let lazy_optional_typ ~hash ~non_preimage ~dummy_value =
  Typ.transport
    Typ.(Field.typ * prover_value ())
    ~there:(function
      | None -> (Lazy.force non_preimage, dummy_value) | Some s -> (hash s, s)
      )
    ~back:(fun (_, s) -> Some s)

let to_input (x, _) = Random_oracle_input.Chunked.field x

let if_ b ~then_ ~else_ =
  let open Run in
  let hash = Field.if_ b ~then_:(fst then_) ~else_:(fst else_) in
  let prover_value =
    exists (Typ.prover_value ())
      ~compute:
        As_prover.(
          fun () ->
            let prover_value =
              if read Boolean.typ b then snd then_ else snd else_
            in
            read (Typ.prover_value ()) prover_value)
  in
  (hash, prover_value)

let make_unsafe hash prover_value : 'a t = (hash, prover_value)

module As_record = struct
  (* it's OK that hash is a Field.t (not a var), bc this is just annotation for the deriver *)
  type 'a t = { data : 'a; hash : Field.t } [@@deriving annot, fields]
end

let deriver inner obj =
  let open Fields_derivers_zkapps in
  let ( !. ) = ( !. ) ~t_fields_annots:As_record.t_fields_annots in
  As_record.Fields.make_creator obj ~data:!.inner ~hash:!.field
  |> finish "Events" ~t_toplevel_annots:As_record.t_toplevel_annots
