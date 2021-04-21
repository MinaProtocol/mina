open Core

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      { fee_payer: Party.Signed.Stable.V1.t
      ; other_parties: Party.Stable.V1.t list
      ; protocol_state: Snapp_predicate.Protocol_state.Stable.V1.t }
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id

    let version_byte = Base58_check.Version_bytes.snapp_command

    let description = "Parties"
  end
end]

include Codable.Make_base58_check (Stable.Latest)

module Valid = struct
  module Stable = Stable

  type t = Stable.Latest.t
end

let check (t : t) =
  let p = t.fee_payer in
  Token_id.(equal default) p.data.body.token_id
  && Sgn.(equal Neg) p.data.body.delta.sgn

let parties (t : t) : Party.t list =
  let p = t.fee_payer in
  { authorization= Control.Signature p.authorization
  ; data= {p.data with predicate= Party.Predicate.Nonce p.data.predicate} }
  :: t.other_parties

(** [fee_lower_bound_exn t] may raise if [check t = false] *)
let fee_lower_bound_exn (t : t) : Currency.Fee.t =
  let x = t.fee_payer.data.body.delta in
  match x.sgn with
  | Neg ->
      Currency.Amount.to_fee x.magnitude
  | Pos ->
      assert false

let fee_payer_party ({fee_payer; _} : t) = fee_payer

let fee_payer (t : t) = Party.Signed.account_id (fee_payer_party t)

let nonce (t : t) : Account.Nonce.t = (fee_payer_party t).data.predicate

let fee_token (t : t) = (fee_payer_party t).data.body.token_id

let accounts_accessed (t : t) =
  List.map (parties t) ~f:(fun p ->
      Account_id.create p.data.body.pk p.data.body.token_id )
  |> List.dedup_and_sort ~compare:Account_id.compare

let fee_payer_pk (t : t) = t.fee_payer.data.body.pk

let value_if b ~then_ ~else_ = if b then then_ else else_

module Virtual = struct
  module First_party = Party

  module Bool = struct
    type t = bool

    let true_ = true

    let assert_ _ = ()

    let equal = Bool.equal

    let not = not

    let ( || ) = ( || )

    let ( && ) = ( && )
  end

  module Unit = struct
    type t = unit

    let if_ = value_if
  end

  module Ledger = Unit
  module Account = Unit

  module Amount = struct
    open Currency.Amount

    type nonrec t = t

    let if_ = value_if

    module Signed = Signed

    let zero = zero

    let ( - ) (x1 : t) (x2 : t) : Signed.t =
      Option.value_exn Signed.(of_unsigned x1 + negate (of_unsigned x2))

    let ( + ) (x1 : t) (x2 : t) : t = Option.value_exn (add x1 x2)

    let add_signed (x1 : t) (x2 : Signed.t) : t =
      let y = Option.value_exn Signed.(of_unsigned x1 + x2) in
      match y.sgn with Pos -> y.magnitude | Neg -> failwith "add_signed"
  end

  module Token_id = struct
    include Token_id

    let if_ = value_if
  end

  module Parties = struct
    type t = Party.t list

    let if_ = value_if

    type party = Party.t

    let empty = []

    let is_empty = List.is_empty

    let pop (t : t) = match t with [] -> failwith "pop" | p :: t -> (p, t)
  end
end

module With_hashes = struct
  type 'a t = ('a * Random_oracle.Digest.t) list

  let empty = Outside_hash_image.t

  let cons ({hash; data} : ('a, 'h) With_hash.t) (t : 'a t) : 'a t =
    let h_tl = match t with [] -> empty | (_, h_tl) :: _ -> h_tl in
    (data, Random_oracle.hash [|hash; h_tl|]) :: t
end

let valid_interval (t : t) =
  let open Snapp_predicate.Closed_interval in
  match t.protocol_state.curr_global_slot with
  | Ignore ->
      Mina_numbers.Global_slot.{lower= zero; upper= max_value}
  | Check i ->
      i
