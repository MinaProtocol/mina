[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
module Coda_numbers = Coda_numbers

[%%else]

module Coda_numbers = Coda_numbers_nonconsensus.Coda_numbers
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Predicate = Snapp_predicate

(*
   For each of the two account's states:
   - before predicate
   - after predicate?
    - set, keep, or ignore
*)

(* This is the statement against which snapp proofs are created. *)
module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('predicate, 'body) t =
        {predicate: 'predicate; body1: 'body; body2: 'body}
      [@@deriving hlist]

      let to_latest = Fn.id
    end
  end]

  let typ spec =
    let open Stable.Latest in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Predicate.Stable.V1.t
      , Snapp_command.Party.Body.Stable.V1.t )
      Poly.Stable.V1.t

    let to_latest = Fn.id
  end
end]

module Checked = struct
  open Pickles.Impls.Step

  type t =
    ( (Predicate.Checked.t, Field.t Set_once.t) With_hash.t
    , (Snapp_command.Party.Body.Checked.t, Field.t Set_once.t) With_hash.t )
    Poly.Stable.Latest.t
end

let typ : (Checked.t, t) Typ.t =
  Poly.typ
    [ Predicate.typ ()
    ; Snapp_command.Party.Body.typ ()
    ; Snapp_command.Party.Body.typ () ]
  |> Typ.transport_var
       ~there:(fun ({predicate; body1; body2} : Checked.t) ->
         { Poly.predicate= With_hash.data predicate
         ; body1= With_hash.data body1
         ; body2= With_hash.data body2 } )
       ~back:(fun ({predicate; body1; body2} : _ Poly.t) ->
         let f = With_hash.of_data ~hash_data:(fun _ -> Set_once.create ()) in
         {Poly.predicate= f predicate; body1= f body1; body2= f body2} )

(*
module Digested = struct
  type t =
    ( Predicate.Digested.t
    , Snapp_command.Party.Body.Digested.t
    )
    Poly.Stable.Latest.t

  let to_input ({ predicate; body1; body2 } : t) =
    let open Random_oracle_input in
    List.reduce_exn ~f:append
      [ predicate
      ; body1
      ; body2
      ]

  module Checked = struct
    type t =
      ( Predicate.Digested.Checked.t
      , Snapp_command.Payload.Digest.Checked.t )
      Poly.Stable.Latest.t

  let to_input ({ predicate; updates } : t) =
    Random_oracle_input.(append
      (Predicate.Digested.Checked.to_input predicate)
      (field updates) )
  end

  let typ : (Checked.t, t) Typ.t =
    Poly.typ [ Predicate.Digested.typ; Snapp_command.Payload.Digest.typ ]
end *)
