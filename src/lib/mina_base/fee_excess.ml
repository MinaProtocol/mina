(** Fee excesses associated with transactions or transitions.

    These are represented as a 'left' and 'right' excess, which describe the
    unresolved fee excesses in the fee tokens of the first (or leftmost) and
    last (or rightmost) transactions in the transition.

    Assumptions:
    * Transactions are grouped by their fee token.
    * The 'fee transfer' transaction to dispense those fees is part of this
      group.
    * The fee excess for each token is 0 across the group.
    * No transactions with fees paid in another token are executed while the
      previous fee token's excess is non-zero.

    By maintaining these assumptions, we can ensure that the un-settled fee
    excesses can be represented by excesses in (at most) 2 tokens.
    Consider, for example, any consecutive subsequence of the transactions

    ..[txn@2][ft@2][txn@3][txn@3][ft@3][txn@4][ft@4][txn@5][txn@5][ft@5][txn@6][ft@6]..

    where [txn@i] and [ft@i] are transactions and fee transfers respectively
    paid in token i.
    The only groups which may have non-zero fee excesses are those which
    contain the start and end of the subsequence.

    The code below also defines a canonical representation where fewer than 2
    tokens have non-zero excesses. See [rebalance] below for details and the
    implementation.
*)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifndef
consensus_mechanism]

open Import

[%%endif]

open Currency

[%%ifdef
consensus_mechanism]

open Snark_params
open Tick

[%%endif]

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('token, 'fee) t =
        { fee_token_l: 'token
        ; fee_excess_l: 'fee
        ; fee_token_r: 'token
        ; fee_excess_r: 'fee }
      [@@deriving compare, equal, hash, sexp, hlist]

      let to_yojson token_to_yojson fee_to_yojson
          {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} =
        `List
          [ `Assoc
              [ ("token", token_to_yojson fee_token_l)
              ; ("amount", fee_to_yojson fee_excess_l) ]
          ; `Assoc
              [ ("token", token_to_yojson fee_token_r)
              ; ("amount", fee_to_yojson fee_excess_r) ] ]

      let of_yojson token_of_yojson fee_of_yojson = function
        | `List
            [ `Assoc [("token", fee_token_l); ("amount", fee_excess_l)]
            ; `Assoc [("token", fee_token_r); ("amount", fee_excess_r)] ] ->
            let open Result.Let_syntax in
            let%map fee_token_l = token_of_yojson fee_token_l
            and fee_excess_l = fee_of_yojson fee_excess_l
            and fee_token_r = token_of_yojson fee_token_r
            and fee_excess_r = fee_of_yojson fee_excess_r in
            {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r}
        | _ ->
            Error "Fee_excess.Poly.Stable.V1.t"
    end
  end]

  [%%define_locally
  Stable.Latest.(to_yojson, of_yojson)]

  [%%ifdef
  consensus_mechanism]

  let typ (token_typ : ('token_var, 'token) Typ.t)
      (fee_typ : ('fee_var, 'fee) Typ.t) :
      (('token_var, 'fee_var) t, ('token, 'fee) t) Typ.t =
    Typ.of_hlistable
      [token_typ; fee_typ; token_typ; fee_typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  [%%endif]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Token_id.Stable.V1.t
      , (Fee.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving compare, equal, hash, sexp, yojson]

    let to_latest = Fn.id
  end
end]

type ('token, 'fee) poly = ('token, 'fee) Poly.t =
  { fee_token_l: 'token
  ; fee_excess_l: 'fee
  ; fee_token_r: 'token
  ; fee_excess_r: 'fee }
[@@deriving compare, equal, hash, sexp]

let poly_to_yojson = Poly.to_yojson

let poly_of_yojson = Poly.of_yojson

[%%ifdef
consensus_mechanism]

type var = (Token_id.var, Fee.Signed.var) poly

let typ : (var, t) Typ.t = Poly.typ Token_id.typ Fee.Signed.typ

let var_of_t ({fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} : t) : var
    =
  { fee_token_l= Token_id.var_of_t fee_token_l
  ; fee_excess_l= Fee.Signed.Checked.constant fee_excess_l
  ; fee_token_r= Token_id.var_of_t fee_token_r
  ; fee_excess_r= Fee.Signed.Checked.constant fee_excess_r }

[%%endif]

let to_input {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} =
  let open Random_oracle.Input in
  List.reduce_exn ~f:append
    [ Token_id.to_input fee_token_l
    ; Fee.Signed.to_input fee_excess_l
    ; Token_id.to_input fee_token_r
    ; Fee.Signed.to_input fee_excess_r ]

[%%ifdef
consensus_mechanism]

let to_input_checked {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} =
  let%map fee_token_l = Token_id.Checked.to_input fee_token_l
  and fee_token_r = Token_id.Checked.to_input fee_token_r in
  List.reduce_exn ~f:Random_oracle.Input.append
    [ fee_token_l
    ; Fee.Signed.Checked.to_input fee_excess_l
    ; fee_token_r
    ; Fee.Signed.Checked.to_input fee_excess_r ]

let assert_equal_checked (t1 : var) (t2 : var) =
  Checked.all_unit
    [ Token_id.Checked.Assert.equal t1.fee_token_l t2.fee_token_l
    ; Fee.Signed.Checked.assert_equal t1.fee_excess_l t2.fee_excess_l
    ; Token_id.Checked.Assert.equal t1.fee_token_r t2.fee_token_r
    ; Fee.Signed.Checked.assert_equal t1.fee_excess_r t2.fee_excess_r ]

[%%endif]

(** Eliminate a fee excess, either by combining it with one to the left/right,
    or by checking that it is zero.
*)
let eliminate_fee_excess (fee_token_l, fee_excess_l)
    (fee_token_m, fee_excess_m) (fee_token_r, fee_excess_r) =
  let add_err x y =
    match Fee.Signed.add x y with
    | Some z ->
        Or_error.return z
    | None ->
        Or_error.errorf "Error adding fees: overflow."
  in
  let open Or_error.Let_syntax in
  if
    Token_id.equal fee_token_l fee_token_m
    || Fee.(equal zero) fee_excess_l.Signed_poly.magnitude
  then
    let%map fee_excess_l = add_err fee_excess_l fee_excess_m in
    ((fee_token_m, fee_excess_l), (fee_token_r, fee_excess_r))
  else if
    Token_id.equal fee_token_r fee_token_m
    || Fee.(equal zero fee_excess_r.Signed_poly.magnitude)
  then
    let%map fee_excess_r = add_err fee_excess_r fee_excess_m in
    ((fee_token_l, fee_excess_l), (fee_token_m, fee_excess_r))
  else if Fee.(equal zero) fee_excess_m.Signed_poly.magnitude then
    return ((fee_token_l, fee_excess_l), (fee_token_r, fee_excess_r))
  else
    Or_error.errorf
      !"Error eliminating fee excess: Excess for token %{sexp: Token_id.t} \
        %{sexp: Fee.Signed.t} was nonzero"
      fee_token_m fee_excess_m

[%%ifdef
consensus_mechanism]

(* We use field elements instead of a currency type here, under the following
   assumptions:
   * the additions and subtractions performed upon members of the currency
     type do not overflow the field size
     - The currency type is currently 64-bit, which is much smaller than the
       field size.
   * it is acceptable for the currency type to overflow/underflow, as long as
     a subsequent subtraction/addition brings it back into the range for the
     currency type.
     - These situations will be rejected by the unchecked code that checks
       each addition/subtraction, but this superset of that behaviour seems
       well-defined, and is still 'correct' in the sense that currency is
       preserved.

   This optimisation saves serveral hundred constraints in the proof by not
   unpacking the result of each arithmetic operation.
*)
let%snarkydef eliminate_fee_excess_checked (fee_token_l, fee_excess_l)
    (fee_token_m, fee_excess_m) (fee_token_r, fee_excess_r) =
  let open Tick in
  let open Checked.Let_syntax in
  let combine (fee_token, fee_excess) fee_excess_m =
    let%bind fee_token_equal = Token_id.Checked.equal fee_token fee_token_m in
    let%bind fee_excess_zero =
      Field.(Checked.equal (Var.constant zero)) fee_excess
    in
    let%bind may_move = Boolean.(fee_token_equal ||| fee_excess_zero) in
    let%bind fee_token =
      Token_id.Checked.if_ fee_excess_zero ~then_:fee_token_m ~else_:fee_token
    in
    let%map fee_excess_to_move =
      Field.Checked.if_ may_move ~then_:fee_excess_m
        ~else_:Field.(Var.constant zero)
    in
    ( (fee_token, Field.Var.add fee_excess fee_excess_to_move)
    , Field.Var.sub fee_excess_m fee_excess_to_move )
  in
  (* NOTE: Below, we may update the tokens on both sides, even though we only
     promote the excess to one of them. This differs from the unchecked
     version, but
     * the token may only be changed if it is associated with 0 fee excess
     * any intermediate 0 fee excesses can always be either combined or erased
       in later eliminations
     * a fee excess of 0 on the left or right will have its token erased to the
       default
  *)
  let%bind (fee_token_l, fee_excess_l), fee_excess_m =
    combine (fee_token_l, fee_excess_l) fee_excess_m
  in
  let%bind (fee_token_r, fee_excess_r), fee_excess_m =
    combine (fee_token_r, fee_excess_r) fee_excess_m
  in
  let%map () =
    [%with_label "Fee excess is eliminated"]
      Field.(Checked.Assert.equal (Var.constant zero) fee_excess_m)
  in
  ((fee_token_l, fee_excess_l), (fee_token_r, fee_excess_r))

[%%endif]

(* 'Rebalance' to a canonical form, where
   - if there is only 1 nonzero excess, it is to the left
   - any zero fee excess has the default token
   - if the fee tokens are the same, the excesses are combined
*)
let rebalance ({fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} : t) =
  let open Or_error.Let_syntax in
  (* Use the same token for both if [fee_excess_l] is zero. *)
  let fee_token_l =
    if Fee.(equal zero) fee_excess_l.magnitude then fee_token_r
    else fee_token_l
  in
  (* Rebalancing. *)
  let%map fee_excess_l, fee_excess_r =
    if Token_id.equal fee_token_l fee_token_r then
      match Fee.Signed.add fee_excess_l fee_excess_r with
      | Some fee_excess_l ->
          return (fee_excess_l, Fee.Signed.zero)
      | None ->
          Or_error.errorf !"Error adding fees: overflow"
    else return (fee_excess_l, fee_excess_r)
  in
  (* Use the default token if the excess is zero.
     This allows [verify_complete_merge] to verify a proof without knowledge of
     the particular fee tokens used.
  *)
  let fee_token_l =
    if Fee.(equal zero) fee_excess_l.magnitude then Token_id.default
    else fee_token_l
  in
  let fee_token_r =
    if Fee.(equal zero) fee_excess_r.magnitude then Token_id.default
    else fee_token_r
  in
  {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r}

[%%ifdef
consensus_mechanism]

let rebalance_checked {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} =
  let open Checked.Let_syntax in
  (* Use the same token for both if [fee_excess_l] is zero. *)
  let%bind fee_token_l =
    let%bind excess_is_zero =
      Field.(Checked.equal (Var.constant zero) fee_excess_l)
    in
    Token_id.Checked.if_ excess_is_zero ~then_:fee_token_r ~else_:fee_token_l
  in
  (* Rebalancing. *)
  let%bind fee_excess_l, fee_excess_r =
    let%bind tokens_equal = Token_id.Checked.equal fee_token_l fee_token_r in
    let%map amount_to_move =
      Field.Checked.if_ tokens_equal ~then_:fee_excess_r
        ~else_:Field.(Var.constant zero)
    in
    ( Field.Var.add fee_excess_l amount_to_move
    , Field.Var.sub fee_excess_r amount_to_move )
  in
  (* Use the default token if the excess is zero. *)
  let%bind fee_token_l =
    let%bind excess_is_zero =
      Field.(Checked.equal (Var.constant zero) fee_excess_l)
    in
    Token_id.Checked.if_ excess_is_zero
      ~then_:Token_id.(var_of_t default)
      ~else_:fee_token_l
  in
  let%map fee_token_r =
    let%bind excess_is_zero =
      Field.(Checked.equal (Var.constant zero) fee_excess_r)
    in
    Token_id.Checked.if_ excess_is_zero
      ~then_:Token_id.(var_of_t default)
      ~else_:fee_token_r
  in
  {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r}

[%%endif]

(** Combine the fee excesses from two transitions. *)
let combine
    { fee_token_l= fee_token1_l
    ; fee_excess_l= fee_excess1_l
    ; fee_token_r= fee_token1_r
    ; fee_excess_r= fee_excess1_r }
    { fee_token_l= fee_token2_l
    ; fee_excess_l= fee_excess2_l
    ; fee_token_r= fee_token2_r
    ; fee_excess_r= fee_excess2_r } =
  let open Or_error.Let_syntax in
  (* Eliminate fee_excess1_r. *)
  let%bind (fee_token1_l, fee_excess1_l), (fee_token2_l, fee_excess2_l) =
    (* [1l; 1r; 2l; 2r] -> [1l; 2l; 2r] *)
    eliminate_fee_excess
      (fee_token1_l, fee_excess1_l)
      (fee_token1_r, fee_excess1_r)
      (fee_token2_l, fee_excess2_l)
  in
  (* Eliminate fee_excess2_l. *)
  let%bind (fee_token1_l, fee_excess1_l), (fee_token2_r, fee_excess2_r) =
    (* [1l; 2l; 2r] -> [1l; 2r] *)
    eliminate_fee_excess
      (fee_token1_l, fee_excess1_l)
      (fee_token2_l, fee_excess2_l)
      (fee_token2_r, fee_excess2_r)
  in
  rebalance
    { fee_token_l= fee_token1_l
    ; fee_excess_l= fee_excess1_l
    ; fee_token_r= fee_token2_r
    ; fee_excess_r= fee_excess2_r }

[%%ifdef
consensus_mechanism]

let%snarkydef combine_checked
    { fee_token_l= fee_token1_l
    ; fee_excess_l= fee_excess1_l
    ; fee_token_r= fee_token1_r
    ; fee_excess_r= fee_excess1_r }
    { fee_token_l= fee_token2_l
    ; fee_excess_l= fee_excess2_l
    ; fee_token_r= fee_token2_r
    ; fee_excess_r= fee_excess2_r } =
  let open Checked.Let_syntax in
  (* Represent amounts as field elements. *)
  let%bind fee_excess1_l = Fee.Signed.Checked.to_field_var fee_excess1_l in
  let%bind fee_excess1_r = Fee.Signed.Checked.to_field_var fee_excess1_r in
  let%bind fee_excess2_l = Fee.Signed.Checked.to_field_var fee_excess2_l in
  let%bind fee_excess2_r = Fee.Signed.Checked.to_field_var fee_excess2_r in
  (* Eliminations. *)
  let%bind (fee_token1_l, fee_excess1_l), (fee_token2_l, fee_excess2_l) =
    (* [1l; 1r; 2l; 2r] -> [1l; 2l; 2r] *)
    [%with_label "Eliminate fee_excess1_r"]
      (eliminate_fee_excess_checked
         (fee_token1_l, fee_excess1_l)
         (fee_token1_r, fee_excess1_r)
         (fee_token2_l, fee_excess2_l))
  in
  let%bind (fee_token1_l, fee_excess1_l), (fee_token2_r, fee_excess2_r) =
    (* [1l; 2l; 2r] -> [1l; 2r] *)
    [%with_label "Eliminate fee_excess2_l"]
      (eliminate_fee_excess_checked
         (fee_token1_l, fee_excess1_l)
         (fee_token2_l, fee_excess2_l)
         (fee_token2_r, fee_excess2_r))
  in
  let%bind {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} =
    rebalance_checked
      { fee_token_l= fee_token1_l
      ; fee_excess_l= fee_excess1_l
      ; fee_token_r= fee_token2_r
      ; fee_excess_r= fee_excess2_r }
  in
  let convert_to_currency excess =
    let%bind currency_excess =
      exists Fee.Signed.typ
        ~compute:
          As_prover.(
            let%map excess = read Field.typ excess in
            let is_neg =
              Bigint.test_bit (Bigint.of_field excess) (Field.size_in_bits - 1)
            in
            let sgn = if is_neg then Sgn.Neg else Sgn.Pos in
            let excess =
              if is_neg then Field.(mul (negate one) excess) else excess
            in
            let magnitude =
              (* TODO: Add a native coercion [Bigint -> UInt64] in Snarky's FFI
                 bindings, use it here.
              *)
              let n = Bigint.of_field excess in
              let total = ref Unsigned_extended.UInt64.zero in
              for i = 0 to Unsigned_extended.UInt64.length_in_bits - 1 do
                if Bigint.test_bit n i then
                  total :=
                    Unsigned_extended.UInt64.(add !total (shift_left one i))
              done ;
              Fee.of_uint64 !total
            in
            Fee.Signed.create ~magnitude ~sgn)
    in
    let%bind excess_from_currency =
      Fee.Signed.Checked.to_field_var currency_excess
    in
    let%map () =
      [%with_label "Fee excess does not overflow"]
        (Field.Checked.Assert.equal excess excess_from_currency)
    in
    currency_excess
  in
  (* Convert to currency. *)
  let%bind fee_excess_l =
    [%with_label "Check for overflow in fee_excess_l"]
      (convert_to_currency fee_excess_l)
  in
  let%map fee_excess_r =
    [%with_label "Check for overflow in fee_excess_r"]
      (convert_to_currency fee_excess_r)
  in
  {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r}

[%%endif]

let empty =
  { fee_token_l= Token_id.default
  ; fee_excess_l= Fee.Signed.zero
  ; fee_token_r= Token_id.default
  ; fee_excess_r= Fee.Signed.zero }

let is_empty {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} =
  Fee.Signed.(equal zero) fee_excess_l
  && Fee.Signed.(equal zero) fee_excess_r
  && Token_id.(equal default) fee_token_l
  && Token_id.(equal default) fee_token_r

let zero = empty

let is_zero = is_empty

let of_single (fee_token_l, fee_excess_l) =
  (* This is safe, we know that we will not hit overflow above. *)
  Or_error.ok_exn
  @@ rebalance
       { fee_token_l
       ; fee_excess_l
       ; fee_token_r= Token_id.default
       ; fee_excess_r= Fee.Signed.zero }

let of_one_or_two excesses =
  let unreduced =
    match excesses with
    | `One (fee_token_l, fee_excess_l) ->
        { fee_token_l
        ; fee_excess_l
        ; fee_token_r= Token_id.default
        ; fee_excess_r= Fee.Signed.zero }
    | `Two ((fee_token_l, fee_excess_l), (fee_token_r, fee_excess_r)) ->
        {fee_token_l; fee_excess_l; fee_token_r; fee_excess_r}
  in
  rebalance unreduced

let to_one_or_two ({fee_token_l; fee_excess_l; fee_token_r; fee_excess_r} : t)
    =
  if Fee.(equal zero) fee_excess_r.magnitude then
    `One (fee_token_l, fee_excess_l)
  else `Two ((fee_token_l, fee_excess_l), (fee_token_r, fee_excess_r))

[%%ifdef
consensus_mechanism]

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map excesses =
    One_or_two.gen (Quickcheck.Generator.tuple2 Token_id.gen Fee.Signed.gen)
  in
  match of_one_or_two excesses with
  | Ok ret ->
      ret
  | Error _ -> (
    (* There is an overflow, just choose the first excess. *)
    match excesses with
    | `One (fee_token_l, fee_excess_l) | `Two ((fee_token_l, fee_excess_l), _)
      ->
        { fee_token_l
        ; fee_excess_l
        ; fee_token_r= Token_id.default
        ; fee_excess_r= Fee.Signed.zero } )

let%test_unit "Checked and unchecked behaviour is consistent" =
  Quickcheck.test (Quickcheck.Generator.tuple2 gen gen) ~f:(fun (fe1, fe2) ->
      let fe = combine fe1 fe2 in
      let fe_checked =
        Or_error.try_with (fun () ->
            Test_util.checked_to_unchecked
              Typ.(typ * typ)
              typ
              (fun (fe1, fe2) -> combine_checked fe1 fe2)
              (fe1, fe2) )
      in
      match (fe, fe_checked) with
      | Ok fe, Ok fe_checked ->
          [%test_eq: t] fe fe_checked
      | Error _, Error _ ->
          ()
      | _ ->
          [%test_eq: t Or_error.t] fe fe_checked )

let%test_unit "Combine succeeds when the middle excess is zero" =
  Quickcheck.test (Quickcheck.Generator.tuple3 gen Token_id.gen Fee.Signed.gen)
    ~f:(fun (fe1, tid, excess) ->
      let tid =
        (* The tokens before and after should be distinct. Especially in this
           scenario, we may get an overflow error otherwise.
        *)
        if Token_id.equal fe1.fee_token_l tid then Token_id.next tid else tid
      in
      let fe2 =
        if Fee.Signed.(equal zero) fe1.fee_excess_r then of_single (tid, excess)
        else
          match
            of_one_or_two
              (`Two
                ( (fe1.fee_token_r, Fee.Signed.negate fe1.fee_excess_r)
                , (tid, excess) ))
          with
          | Ok fe2 ->
              fe2
          | Error _ ->
              (* The token is the same, and rebalancing causes an overflow. *)
              of_single (fe1.fee_token_r, Fee.Signed.negate fe1.fee_excess_r)
      in
      ignore @@ Or_error.ok_exn (combine fe1 fe2) )

[%%endif]
