open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type ('u, 's) t =
            ('u, 's) Mina_wire_types.Mina_base.User_command.Poly.V2.t =
        | Signed_command of 'u
        | Zkapp_command of 's
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end

    module V1 = struct
      type ('u, 's) t = Signed_command of 'u | Snapp_command of 's
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest : _ t -> _ V2.t = function
        | Signed_command x ->
            Signed_command x
        | Snapp_command _ ->
            failwith "Snapp_command"
    end
  end]
end

type ('u, 's) t_ = ('u, 's) Poly.Stable.Latest.t =
  | Signed_command of 'u
  | Zkapp_command of 's

module Gen_make (C : Signed_command_intf.Gen_intf) = struct
  let to_signed_command f =
    Quickcheck.Generator.map f ~f:(fun c -> Signed_command c)

  open C.Gen

  let payment ?sign_type ~key_gen ?nonce ~max_amount ~fee_range () =
    to_signed_command
      (payment ?sign_type ~key_gen ?nonce ~max_amount ~fee_range ())

  let payment_with_random_participants ?sign_type ~keys ?nonce ~max_amount
      ~fee_range () =
    to_signed_command
      (payment_with_random_participants ?sign_type ~keys ?nonce ~max_amount
         ~fee_range () )

  let stake_delegation ~key_gen ?nonce ~fee_range () =
    to_signed_command (stake_delegation ~key_gen ?nonce ~fee_range ())

  let stake_delegation_with_random_participants ~keys ?nonce ~fee_range () =
    to_signed_command
      (stake_delegation_with_random_participants ~keys ?nonce ~fee_range ())

  let sequence ?length ?sign_type a =
    Quickcheck.Generator.map
      (sequence ?length ?sign_type a)
      ~f:(List.map ~f:(fun c -> Signed_command c))
end

module Gen = Gen_make (Signed_command)

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      (Signed_command.Stable.V2.t, Zkapp_command.Stable.V1.t) Poly.Stable.V2.t
    [@@deriving sexp, compare, equal, hash, yojson]

    let to_latest = Fn.id
  end
end]

let to_base64 : t -> string = function
  | Signed_command sc ->
      Signed_command.to_base64 sc
  | Zkapp_command zc ->
      Zkapp_command.to_base64 zc

let of_base64 s : t Or_error.t =
  match Signed_command.of_base64 s with
  | Ok sc ->
      Ok (Signed_command sc)
  | Error err1 -> (
      match Zkapp_command.of_base64 s with
      | Ok zc ->
          Ok (Zkapp_command zc)
      | Error err2 ->
          Error
            (Error.of_string
               (sprintf
                  "Could decode Base64 neither to signed command (%s), nor to \
                   zkApp (%s)"
                  (Error.to_string_hum err1) (Error.to_string_hum err2) ) ) )

(*
include Allocation_functor.Make.Versioned_v1.Full_compare_eq_hash (struct
  let id = "user_command"

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        (Signed_command.Stable.V1.t, Snapp_command.Stable.V1.t) Poly.Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id

      type 'a creator : Signed_command.t -> Snapp_command.t -> 'a

      let create cmd1 cmd2 = (cmd1, cmd2)
    end
  end]
end)
*)

module Zero_one_or_two = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = [ `Zero | `One of 'a | `Two of 'a * 'a ]
      [@@deriving sexp, compare, equal, hash, yojson]
    end
  end]
end

module Verifiable = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Signed_command.Stable.V2.t
        , Zkapp_command.Verifiable.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let fee_payer (t : t) =
    match t with
    | Signed_command x ->
        Signed_command.fee_payer x
    | Zkapp_command p ->
        Account_update.Fee_payer.account_id p.fee_payer
end

let to_verifiable (t : t) ~ledger ~get ~location_of_account : Verifiable.t =
  let find_vk (p : Account_update.t) =
    let ( ! ) x = Option.value_exn x in
    let id = Account_update.account_id p in
    Option.try_with (fun () ->
        let account : Account.t =
          !(get ledger !(location_of_account ledger id))
        in
        !(!(account.zkapp).verification_key) )
  in
  match t with
  | Signed_command c ->
      Signed_command c
  | Zkapp_command { fee_payer; account_updates; memo } ->
      Zkapp_command
        { fee_payer
        ; account_updates =
            account_updates
            |> Zkapp_command.Call_forest.map ~f:(fun account_update ->
                   (account_update, find_vk account_update) )
        ; memo
        }

let of_verifiable (t : Verifiable.t) : t =
  match t with
  | Signed_command x ->
      Signed_command x
  | Zkapp_command p ->
      Zkapp_command (Zkapp_command.of_verifiable p)

let fee : t -> Currency.Fee.t = function
  | Signed_command x ->
      Signed_command.fee x
  | Zkapp_command p ->
      Zkapp_command.fee p

(* for filtering *)
let minimum_fee = Mina_compile_config.minimum_user_command_fee

let has_insufficient_fee t = Currency.Fee.(fee t < minimum_fee)

let accounts_accessed (t : t) =
  match t with
  | Signed_command x ->
      Signed_command.accounts_accessed x
  | Zkapp_command ps ->
      Zkapp_command.accounts_accessed ps

let to_base58_check (t : t) =
  match t with
  | Signed_command x ->
      Signed_command.to_base58_check x
  | Zkapp_command ps ->
      Zkapp_command.to_base58_check ps

let fee_payer (t : t) =
  match t with
  | Signed_command x ->
      Signed_command.fee_payer x
  | Zkapp_command p ->
      Zkapp_command.fee_payer p

(** The application nonce is the nonce of the fee payer at which a user command can be applied. *)
let applicable_at_nonce (t : t) =
  match t with
  | Signed_command x ->
      Signed_command.nonce x
  | Zkapp_command p ->
      Zkapp_command.applicable_at_nonce p

let expected_target_nonce t = Account.Nonce.succ (applicable_at_nonce t)

(** The target nonce is what the nonce of the fee payer will be after a user command is successfully applied. *)
let target_nonce_on_success (t : t) =
  match t with
  | Signed_command x ->
      Account.Nonce.succ (Signed_command.nonce x)
  | Zkapp_command p ->
      Zkapp_command.target_nonce_on_success p

let fee_token (t : t) =
  match t with
  | Signed_command x ->
      Signed_command.fee_token x
  | Zkapp_command x ->
      Zkapp_command.fee_token x

let valid_until (t : t) =
  match t with
  | Signed_command x ->
      Signed_command.valid_until x
  | Zkapp_command _ ->
      Mina_numbers.Global_slot.max_value

module Valid = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Signed_command.With_valid_signature.Stable.V2.t
        , Zkapp_command.Valid.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  module Gen = Gen_make (Signed_command.With_valid_signature)
end

let check ~ledger ~get ~location_of_account (t : t) : Valid.t option =
  match t with
  | Signed_command x ->
      Option.map (Signed_command.check x) ~f:(fun c -> Signed_command c)
  | Zkapp_command p ->
      Option.map
        (Zkapp_command.Valid.to_valid ~ledger ~get ~location_of_account p)
        ~f:(fun p -> Zkapp_command p)

let forget_check (t : Valid.t) : t =
  match t with
  | Zkapp_command x ->
      Zkapp_command (Zkapp_command.Valid.forget x)
  | Signed_command c ->
      Signed_command (c :> Signed_command.t)

let to_valid_unsafe (t : t) =
  `If_this_is_used_it_should_have_a_comment_justifying_it
    ( match t with
    | Zkapp_command x ->
        let (`If_this_is_used_it_should_have_a_comment_justifying_it x) =
          Zkapp_command.Valid.to_valid_unsafe x
        in
        Zkapp_command x
    | Signed_command x ->
        (* This is safe due to being immediately wrapped again. *)
        let (`If_this_is_used_it_should_have_a_comment_justifying_it x) =
          Signed_command.to_valid_unsafe x
        in
        Signed_command x )

let filter_by_participant (commands : t list) public_key =
  List.filter commands ~f:(fun user_command ->
      Core_kernel.List.exists
        (accounts_accessed user_command)
        ~f:
          (Fn.compose
             (Signature_lib.Public_key.Compressed.equal public_key)
             Account_id.public_key ) )

(* A metric on user commands that should correspond roughly to resource costs
   for validation/application *)
let weight : t -> int = function
  | Signed_command signed_command ->
      Signed_command.payload signed_command |> Signed_command_payload.weight
  | Zkapp_command zkapp_command ->
      Zkapp_command.weight zkapp_command

(* Fee per weight unit *)
let fee_per_wu (user_command : Stable.Latest.t) : Currency.Fee_rate.t =
  (*TODO: return Or_error*)
  Currency.Fee_rate.make_exn (fee user_command) (weight user_command)

let valid_size ~genesis_constants = function
  | Signed_command _ ->
      Ok ()
  | Zkapp_command zkapp_command ->
      Zkapp_command.valid_size ~genesis_constants zkapp_command
