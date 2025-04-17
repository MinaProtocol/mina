(* TODO: remove type generalizations #2594 *)

open Core_kernel
open Transaction_snark
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

module Compact = struct
  module Single = struct
    module Spec = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type ('witness, 'ledger_proof) t =
            | Transition of Statement.Stable.V2.t * 'witness
            | Merge of Statement.Stable.V2.t * 'ledger_proof * 'ledger_proof
          [@@deriving sexp, yojson]

          let to_latest = Fn.id
        end
      end]

      type ('witness, 'ledger_proof) t =
            ('witness, 'ledger_proof) Stable.Latest.t =
        | Transition of Statement.Stable.Latest.t * 'witness
        | Merge of Statement.Stable.Latest.t * 'ledger_proof * 'ledger_proof
      [@@deriving sexp, yojson]

      let map ~f_witness ~f_proof = function
        | Transition (s, w) ->
            Transition (s, f_witness w)
        | Merge (s, p1, p2) ->
            Merge (s, f_proof p1, f_proof p2)

      let witness (t : (_, _) t) =
        match t with Transition (_, witness) -> Some witness | Merge _ -> None

      let statement = function Transition (s, _) -> s | Merge (s, _, _) -> s

      let gen :
             'witness Quickcheck.Generator.t
          -> 'ledger_proof Quickcheck.Generator.t
          -> ('witness, 'ledger_proof) t Quickcheck.Generator.t =
       fun gen_witness gen_proof ->
        let open Quickcheck.Generator in
        let gen_transition =
          let open Let_syntax in
          let%bind statement = Statement.gen in
          let%map witness = gen_witness in
          Transition (statement, witness)
        in
        let gen_merge =
          let open Let_syntax in
          let%bind statement = Statement.gen in
          let%map p1, p2 = tuple2 gen_proof gen_proof in
          Merge (statement, p1, p2)
        in
        union [ gen_transition; gen_merge ]
    end
  end

  module Spec = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'single t =
          { instances : 'single One_or_two.Stable.V1.t
          ; fee : Currency.Fee.Stable.V1.t
          }
        [@@deriving fields, sexp, to_yojson]
      end
    end]

    let map ~f_single { instances; fee } =
      { instances = One_or_two.map ~f:f_single instances; fee }

    let map_opt ~f_single { instances; fee } =
      let open Option.Let_syntax in
      let%map instances = One_or_two.Option.map ~f:f_single instances in
      { instances; fee }
  end
end

(* A `Pairing.t` identifies a single work in Work_selector's perspective *)
module Pairing = struct
  module UUID = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* this identifies a One_or_two work from Work_selector's perspective *)
        type t = Pairing_UUID of int
        [@@deriving compare, hash, sexp, yojson, equal]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      (* Case `One` indicate no need to pair. This is needed because zkapp command
         might be left in pool of half completion. *)
      type t =
        { one_or_two : [ `First | `Second | `One ]
        ; pair_uuid : UUID.Stable.V1.t
        }
      [@@deriving compare, hash, sexp, yojson, equal]

      let to_latest = Fn.id
    end
  end]
end

(* this is the actual work passed over network between coordinator and worker *)
module Wire = struct
  module Regular_work_single = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          ( Transaction_witness.Stable.V2.t
          , Ledger_proof.Stable.V2.t )
          Compact.Single.Spec.Stable.V2.t
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Zkapp_command_job = struct
    (* A Zkapp_command_job.t`this identifies a single `Zkapp_command_job` *)
    module UUID = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t = Job_UUID of int [@@deriving compare, hash, sexp, yojson]

          let to_latest = Fn.id
        end
      end]
    end

    module Spec = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t =
            | Segment of
                { statement : Statement.Stable.V2.t
                ; witness : Zkapp_command_segment.Witness.Stable.V1.t
                ; spec : Zkapp_command_segment.Basic.Stable.V1.t
                }
            | Merge of
                { statement : Statement.Stable.V2.t
                ; proof1 : Ledger_proof.Stable.V2.t
                ; proof2 : Ledger_proof.Stable.V2.t
                }
          [@@deriving sexp, yojson]

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { spec : Spec.Stable.V1.t
          ; pairing_id : Pairing.Stable.V1.t
          ; job_uuid : UUID.Stable.V1.t
          }
        [@@deriving sexp, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Single = struct
    module Spec = struct
      [%%versioned
      module Stable = struct
        module V2 = struct
          type t =
            | Regular of Regular_work_single.Stable.V1.t
            | Sub_zkapp_command of Zkapp_command_job.Stable.V1.t
          [@@deriving sexp, yojson]

          let to_latest = Fn.id
        end

        module V1 = struct
          type t = Regular_work_single.Stable.V1.t [@@deriving sexp, yojson]

          let to_latest (t : t) : V2.t = Regular t
        end
      end]

      type t = Stable.Latest.t [@@deriving sexp, yojson]

      let map_regular_witness ~f = function
        | Regular work ->
            Regular (Compact.Single.Spec.map ~f_witness:f ~f_proof:Fn.id work)
        | Sub_zkapp_command seg ->
            Sub_zkapp_command seg

      let statement : t -> Statement.Stable.V2.t = function
        | Regular regular ->
            Compact.Single.Spec.statement regular
        | Sub_zkapp_command
            { spec = Segment { statement; _ } | Merge { statement; _ }; _ } ->
            statement

      let transaction : t -> Mina_transaction.Transaction.Stable.V2.t option =
        function
        | Regular work ->
            work |> Compact.Single.Spec.witness
            |> Option.map ~f:(fun w ->
                   w.Transaction_witness.Stable.V2.transaction )
        | Sub_zkapp_command _ ->
            None
    end
  end
end

let update_metric :
       Core.Time.Stable.Span.V1.t * [ `Transition | `Merge ]
    -> Core.Time.Stable.Span.V1.t
       * [ `Transition | `Merge | `Zkapp_command_segment ] = function
  | span, `Transition ->
      (span, `Transition)
  | span, `Merge ->
      (span, `Merge)

module Result = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('spec, 'proof) t =
        { proofs : 'proof One_or_two.Stable.V1.t
        ; metrics :
            ( Core.Time.Stable.Span.V1.t
            * [ `Transition | `Merge | `Zkapp_command_segment ] )
            One_or_two.Stable.V1.t
        ; spec : 'spec
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
      [@@deriving fields]
    end

    module V1 = struct
      type ('spec, 'proof) t =
        { proofs : 'proof One_or_two.Stable.V1.t
        ; metrics :
            (Core.Time.Stable.Span.V1.t * [ `Transition | `Merge ])
            One_or_two.Stable.V1.t
        ; spec : 'spec
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
      [@@deriving fields]

      let to_latest ({ proofs; metrics; spec; prover } : ('spec, 'single) t) :
          ('spec, 'single) V2.t =
        { proofs
        ; metrics = One_or_two.map ~f:update_metric metrics
        ; spec
        ; prover
        }
    end
  end]

  let map ~f_spec ~f_single { proofs; metrics; spec; prover } =
    { proofs = One_or_two.map ~f:f_single proofs
    ; metrics
    ; spec = f_spec spec
    ; prover
    }

  let map_opt ~f_spec ~f_single { proofs; metrics; spec; prover } =
    let open Option.Let_syntax in
    let%bind proofs = One_or_two.Option.map ~f:f_single proofs in
    let%map spec = f_spec spec in
    { proofs; metrics; spec; prover }
end

module Result_zkapp_command_segment = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'proof t =
        { id : int
        ; proofs : 'proof One_or_two.Stable.V1.t
        ; metrics :
            (Core.Time.Stable.Span.V1.t * [ `Transition | `Merge ])
            One_or_two.Stable.V1.t
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }
      [@@deriving fields]
    end
  end]
end

module Result_without_metrics = struct
  type 'proof t =
    { proofs : 'proof One_or_two.t
    ; statements : Statement.t One_or_two.t
    ; prover : Signature_lib.Public_key.Compressed.t
    ; fee : Currency.Fee.t
    }
  [@@deriving yojson, sexp]
end
