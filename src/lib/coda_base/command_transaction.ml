open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('u, 's) t = User_command of 'u | Snapp_command of 's
      [@@deriving sexp, compare, eq, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

type ('u, 's) t_ = ('u, 's) Poly.Stable.Latest.t =
  | User_command of 'u
  | Snapp_command of 's

(* TODO: For now, we don't generate snapp transactions. *)
module Gen_make (C : User_command_intf.Gen_intf) = struct
  let f g = Quickcheck.Generator.map g ~f:(fun c -> User_command c)

  open C.Gen

  let payment ?sign_type ~key_gen ?nonce ~max_amount ?fee_token ?payment_token
      ~max_fee () =
    f
      (payment ?sign_type ~key_gen ?nonce ~max_amount ?fee_token ?payment_token
         ~max_fee ())

  let payment_with_random_participants ?sign_type ~keys ?nonce ~max_amount
      ?fee_token ?payment_token ~max_fee () =
    f
      (payment_with_random_participants ?sign_type ~keys ?nonce ~max_amount
         ?fee_token ?payment_token ~max_fee ())

  let stake_delegation ~key_gen ?nonce ?fee_token ~max_fee () =
    f (stake_delegation ~key_gen ?nonce ?fee_token ~max_fee ())

  let stake_delegation_with_random_participants ~keys ?nonce ?fee_token
      ~max_fee () =
    f
      (stake_delegation_with_random_participants ~keys ?nonce ?fee_token
         ~max_fee ())

  let sequence ?length ?sign_type a =
    Quickcheck.Generator.map
      (sequence ?length ?sign_type a)
      ~f:(List.map ~f:(fun c -> User_command c))
end

module Gen = Gen_make (User_command)

module Valid = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( User_command.With_valid_signature.Stable.V1.t
        , Snapp_command.Valid.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, compare, eq, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  module Gen = Gen_make (User_command.With_valid_signature)
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      (User_command.Stable.V1.t, Snapp_command.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id
  end
end]

module Zero_one_or_two = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = [`Zero | `One of 'a | `Two of 'a * 'a]
      [@@deriving sexp, compare, eq, hash, yojson]
    end
  end]
end

module Verifiable = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( User_command.Stable.V1.t
        , Snapp_command.Stable.V1.t
          * (* TODO: Should be Coda_base.Side_loaded_verification_key *)
          Pickles.Side_loaded.Verification_key.Stable.V1.t
          Zero_one_or_two.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, compare, eq, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

let to_verifiable_exn (t : t) ~ledger ~get ~location_of_account =
  let find_vk c pk =
    let ( ! ) x = Option.value_exn x in
    let id = Account_id.create pk (Snapp_command.token_id c) in
    let account : Account.t = !(get ledger !(location_of_account ledger id)) in
    !(!(account.snapp).verification_key).data
  in
  let of_list = function
    | [] ->
        `Zero
    | [x] ->
        `One x
    | [x; y] ->
        `Two (x, y)
    | _ ->
        failwith "of_list"
  in
  match t with
  | User_command c ->
      User_command c
  | Snapp_command c ->
      let pks =
        match c with
        | Proved_proved r ->
            [r.one.data.body.pk; r.two.data.body.pk]
        | Proved_empty r ->
            [r.one.data.body.pk]
        | Proved_signed r ->
            [r.one.data.body.pk]
        | Signed_signed _ | Signed_empty _ ->
            []
      in
      Snapp_command (c, of_list (List.map ~f:(find_vk c) pks))

let to_verifiable t ~ledger ~get ~location_of_account =
  Option.try_with (fun () ->
      to_verifiable_exn t ~ledger ~get ~location_of_account )

let fee_exn : t -> Currency.Fee.t = function
  | User_command x ->
      User_command.fee x
  | Snapp_command x ->
      Snapp_command.fee_exn x

(* for filtering *)
let minimum_fee = Coda_compile_config.minimum_user_command_fee

let has_insufficient_fee t = Currency.Fee.(fee_exn t < minimum_fee)

let accounts_accessed (t : t) ~next_available_token =
  match t with
  | User_command x ->
      User_command.accounts_accessed x ~next_available_token
  | Snapp_command x ->
      Snapp_command.accounts_accessed x

let next_available_token (t : t) tok =
  match t with
  | User_command x ->
      User_command.next_available_token x tok
  | Snapp_command x ->
      Snapp_command.next_available_token x tok

let to_base58_check (t : t) =
  match t with
  | User_command x ->
      User_command.to_base58_check x
  | Snapp_command x ->
      Snapp_command.to_base58_check x

let fee_payer (t : t) =
  match t with
  | User_command x ->
      User_command.fee_payer x
  | Snapp_command x ->
      Snapp_command.fee_payer x

let nonce_exn (t : t) =
  match t with
  | User_command x ->
      User_command.nonce x
  | Snapp_command x ->
      Option.value_exn (Snapp_command.nonce x)

let check_tokens (t : t) =
  match t with
  | User_command x ->
      User_command.check_tokens x
  | Snapp_command x ->
      Snapp_command.check_tokens x

let fee_token (t : t) =
  match t with
  | User_command x ->
      User_command.fee_token x
  | Snapp_command x ->
      Snapp_command.fee_token x

let forget_check (t : Valid.t) : t = (t :> t)

let to_valid_unsafe (t : t) =
  `If_this_is_used_it_should_have_a_comment_justifying_it
    ( match t with
    | Snapp_command x ->
        Snapp_command x
    | User_command x ->
        (* This is safe due to being immediately wrapped again. *)
        let (`If_this_is_used_it_should_have_a_comment_justifying_it x) =
          User_command.to_valid_unsafe x
        in
        User_command x )

let filter_by_participant (commands : t list) public_key =
  List.filter commands ~f:(fun user_command ->
      Core_kernel.List.exists
        (accounts_accessed ~next_available_token:Token_id.invalid user_command)
        ~f:
          (Fn.compose
             (Signature_lib.Public_key.Compressed.equal public_key)
             Account_id.public_key) )
