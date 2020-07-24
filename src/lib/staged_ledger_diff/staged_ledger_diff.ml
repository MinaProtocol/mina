open Core_kernel
open Coda_base
open Signature_lib

module At_most_two = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
      [@@deriving sexp, to_yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t =
    | Zero
    | One of 'a option
    | Two of ('a * 'a option) option
  [@@deriving sexp, to_yojson]

  let increase t ws =
    match (t, ws) with
    | Zero, [] ->
        Ok (One None)
    | Zero, [a] ->
        Ok (One (Some a))
    | One _, [] ->
        Ok (Two None)
    | One _, [a] ->
        Ok (Two (Some (a, None)))
    | One _, [a; a'] ->
        Ok (Two (Some (a', Some a)))
    | _ ->
        Or_error.error_string "Error incrementing coinbase parts"
end

module At_most_one = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = Zero | One of 'a option [@@deriving sexp, to_yojson]
    end
  end]

  type 'a t = 'a Stable.Latest.t = Zero | One of 'a option
  [@@deriving sexp, to_yojson]

  let increase t ws =
    match (t, ws) with
    | Zero, [] ->
        Ok (One None)
    | Zero, [a] ->
        Ok (One (Some a))
    | _ ->
        Or_error.error_string "Error incrementing coinbase parts"
end

module Ft = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Coinbase.Fee_transfer.Stable.V1.t [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]
end

module Pre_diff_two = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('a, 'b) t =
        { completed_works: 'a list
        ; user_commands: 'b list
        ; coinbase: Ft.Stable.V1.t At_most_two.Stable.V1.t }
      [@@deriving sexp, to_yojson]
    end
  end]

  type ('a, 'b) t = ('a, 'b) Stable.Latest.t =
    { completed_works: 'a list
    ; user_commands: 'b list
    ; coinbase: Ft.t At_most_two.t }
  [@@deriving sexp, to_yojson]
end

module Pre_diff_one = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('a, 'b) t =
        { completed_works: 'a list
        ; user_commands: 'b list
        ; coinbase: Ft.Stable.V1.t At_most_one.Stable.V1.t }
      [@@deriving sexp, to_yojson]
    end
  end]

  type ('a, 'b) t = ('a, 'b) Stable.Latest.t =
    { completed_works: 'a list
    ; user_commands: 'b list
    ; coinbase: Ft.t At_most_one.t }
  [@@deriving sexp, to_yojson]
end

module Pre_diff_with_at_most_two_coinbase = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Transaction_snark_work.Stable.V1.t
        , User_command.Stable.V1.t With_status.Stable.V1.t )
        Pre_diff_two.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]
end

module Pre_diff_with_at_most_one_coinbase = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Transaction_snark_work.Stable.V1.t
        , User_command.Stable.V1.t With_status.Stable.V1.t )
        Pre_diff_one.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]
end

module Diff = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        Pre_diff_with_at_most_two_coinbase.Stable.V1.t
        * Pre_diff_with_at_most_one_coinbase.Stable.V1.t option
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp, to_yojson]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { diff: Diff.Stable.V1.t
      ; creator: Public_key.Compressed.Stable.V1.t
      ; coinbase_receiver: Public_key.Compressed.Stable.V1.t }
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t =
  { diff: Diff.t
  ; creator: Public_key.Compressed.t
  ; coinbase_receiver: Public_key.Compressed.t }
[@@deriving sexp, to_yojson, fields]

module With_valid_signatures_and_proofs = struct
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.With_valid_signature.t With_status.t )
    Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.Checked.t
    , User_command.With_valid_signature.t With_status.t )
    Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, to_yojson]

  type t =
    { diff: diff
    ; creator: Public_key.Compressed.t
    ; coinbase_receiver: Public_key.Compressed.t }
  [@@deriving sexp, to_yojson]

  let user_commands t =
    (fst t.diff).user_commands
    @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.user_commands)
end

let forget_cw cw_list = List.map ~f:Transaction_snark_work.forget cw_list

module With_valid_signatures = struct
  type pre_diff_with_at_most_two_coinbase =
    ( Transaction_snark_work.t
    , User_command.With_valid_signature.t With_status.t )
    Pre_diff_two.t
  [@@deriving sexp, to_yojson]

  type pre_diff_with_at_most_one_coinbase =
    ( Transaction_snark_work.t
    , User_command.With_valid_signature.t With_status.t )
    Pre_diff_one.t
  [@@deriving sexp, to_yojson]

  type diff =
    pre_diff_with_at_most_two_coinbase
    * pre_diff_with_at_most_one_coinbase option
  [@@deriving sexp, to_yojson]

  type t =
    { diff: diff
    ; creator: Public_key.Compressed.t
    ; coinbase_receiver: Public_key.Compressed.t }
  [@@deriving sexp, to_yojson]
end

let validate_user_commands (t : t)
    ~(check : User_command.t -> User_command.With_valid_signature.t option) :
    (With_valid_signatures.t, User_command.t With_status.t) result =
  let open Result.Let_syntax in
  let validate user_commands =
    let%map user_commands' =
      List.fold_until user_commands ~init:[]
        ~f:(fun acc t ->
          match With_status.map_opt ~f:check t with
          | Some t ->
              Continue (t :: acc)
          | None ->
              Stop (Error t) )
        ~finish:(fun acc -> Ok acc)
    in
    List.rev user_commands'
  in
  let d1 = fst t.diff in
  let%bind p1 =
    let%map user_commands = validate d1.user_commands in
    ( { completed_works= d1.completed_works
      ; user_commands
      ; coinbase= d1.coinbase }
      : With_valid_signatures.pre_diff_with_at_most_two_coinbase )
  in
  let%map p2 =
    Option.value_map ~default:(Ok None) (snd t.diff) ~f:(fun d2 ->
        let%map user_commands = validate d2.user_commands in
        Some
          { Pre_diff_one.completed_works= d2.completed_works
          ; user_commands
          ; coinbase= d2.coinbase } )
  in
  ( {creator= t.creator; coinbase_receiver= t.coinbase_receiver; diff= (p1, p2)}
    : With_valid_signatures.t )

let forget_proof_checks (d : With_valid_signatures_and_proofs.t) :
    With_valid_signatures.t =
  let d1 = fst d.diff in
  let p1 : With_valid_signatures.pre_diff_with_at_most_two_coinbase =
    { completed_works= forget_cw d1.completed_works
    ; user_commands= d1.user_commands
    ; coinbase= d1.coinbase }
  in
  let p2 =
    Option.map (snd d.diff) ~f:(fun d2 ->
        ( { completed_works= forget_cw d2.completed_works
          ; user_commands= d2.user_commands
          ; coinbase= d2.coinbase }
          : With_valid_signatures.pre_diff_with_at_most_one_coinbase ) )
  in
  {creator= d.creator; coinbase_receiver= d.coinbase_receiver; diff= (p1, p2)}

let forget_pre_diff_with_at_most_two
    (pre_diff :
      With_valid_signatures_and_proofs.pre_diff_with_at_most_two_coinbase) :
    Pre_diff_with_at_most_two_coinbase.t =
  { completed_works= forget_cw pre_diff.completed_works
  ; user_commands= (pre_diff.user_commands :> User_command.t With_status.t list)
  ; coinbase= pre_diff.coinbase }

let forget_pre_diff_with_at_most_one
    (pre_diff :
      With_valid_signatures_and_proofs.pre_diff_with_at_most_one_coinbase) =
  { Pre_diff_one.completed_works= forget_cw pre_diff.completed_works
  ; user_commands= (pre_diff.user_commands :> User_command.t With_status.t list)
  ; coinbase= pre_diff.coinbase }

let forget (t : With_valid_signatures_and_proofs.t) =
  { diff=
      ( forget_pre_diff_with_at_most_two (fst t.diff)
      , Option.map (snd t.diff) ~f:forget_pre_diff_with_at_most_one )
  ; coinbase_receiver= t.coinbase_receiver
  ; creator= t.creator }

let user_commands (t : t) =
  (fst t.diff).user_commands
  @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.user_commands)

let completed_works (t : t) =
  (fst t.diff).completed_works
  @ Option.value_map (snd t.diff) ~default:[] ~f:(fun d -> d.completed_works)

let coinbase ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    (t : t) =
  let first_pre_diff, second_pre_diff_opt = t.diff in
  match
    ( first_pre_diff.coinbase
    , Option.value_map second_pre_diff_opt ~default:At_most_one.Zero
        ~f:(fun d -> d.coinbase) )
  with
  | At_most_two.Zero, At_most_one.Zero ->
      Currency.Amount.zero
  | _ ->
      constraint_constants.coinbase_amount
