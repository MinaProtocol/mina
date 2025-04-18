open Core_kernel
open Transaction_snark
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

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

  let map_biased ~f_single { instances; fee } =
    let instances =
      match instances with
      | `One i ->
          `One (f_single ~one_or_two:`One i)
      | `Two (l, r) ->
          `Two (f_single ~one_or_two:`First l, f_single ~one_or_two:`Second r)
    in
    { instances; fee }

  let map_opt ~f_single { instances; fee } =
    let open Option.Let_syntax in
    let%map instances = One_or_two.Option.map ~f:f_single instances in
    { instances; fee }
end

(* TODO: we don't want `Zkapp_command_segment *)

let update_metric :
       Core.Time.Stable.Span.V1.t * [ `Transition | `Merge ]
    -> Core.Time.Stable.Span.V1.t
       * [ `Transition | `Merge | `Zkapp_command_segment ] = function
  | span, `Transition ->
      (span, `Transition)
  | span, `Merge ->
      (span, `Merge)

(* Since we may return parts of One_or_two, we need a new type to track it  *)
module Partitoned = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = [ `One of 'a | `Two of 'a * 'a | `First of 'a | `Second of 'a ]
    end
  end]

  let of_one_or_two : 'a One_or_two.t -> 'a t = function
    | `One a ->
        `One a
    | `Two (a, b) ->
        `Two (a, b)

  let to_one_or_two : 'a t -> 'a One_or_two.t option = function
    | `One a ->
        Some (`One a)
    | `Two (a, b) ->
        Some (`Two (a, b))
    | `First _ | `Second _ ->
        None

  let map (t : 'a t) ~f =
    match t with
    | `One a ->
        `One (f a)
    | `Two (a, b) ->
        `Two (f a, f b)
    | `First a ->
        `First (f a)
    | `Second a ->
        `Second (f a)

  let map_opt (t : 'a t) ~f =
    let open Option.Let_syntax in
    match t with
    | `One a ->
        let%map f_a = f a in
        `One f_a
    | `Two (a, b) ->
        let%bind f_a = f a in
        let%map f_b = f b in
        `Two (f_a, f_b)
    | `First a ->
        let%map f_a = f a in
        `First f_a
    | `Second a ->
        let%map f_a = f a in
        `Second f_a
end

module Result = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('spec, 'proof) t =
        { proofs : 'proof Partitoned.Stable.V1.t
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
        { proofs = Partitoned.of_one_or_two proofs
        ; metrics = One_or_two.map ~f:update_metric metrics
        ; spec
        ; prover
        }
    end
  end]

  let map ~f_spec ~f_single { proofs; metrics; spec; prover } =
    { proofs = Partitoned.map ~f:f_single proofs
    ; metrics
    ; spec = f_spec spec
    ; prover
    }

  let map_opt ~f_spec ~f_single { proofs; metrics; spec; prover } =
    let open Option.Let_syntax in
    let%bind proofs = Partitoned.map_opt ~f:f_single proofs in
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
