[%%import
"../../config.mlh"]

open Core
open Import
open Coda_numbers
open Module_version
module Fee = Currency.Fee
module Payload = User_command_payload

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('payload, 'pk, 'signature) t =
          {payload: 'payload; sender: 'pk; signature: 'signature}
        [@@deriving bin_io, compare, sexp, hash, yojson, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('payload, 'pk, 'signature) t =
        ('payload, 'pk, 'signature) Stable.Latest.t =
    {payload: 'payload; sender: 'pk; signature: 'signature}
  [@@deriving sexp, hash, yojson]
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        ( Payload.Stable.V1.t
        , Public_key.Stable.V1.t
        , Signature.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving bin_io, compare, sexp, hash, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
    include Comparable.Make (T)
    include Hashable.Make (T)

    let accounts_accessed ({payload; sender; _} : t) =
      Public_key.compress sender :: Payload.accounts_accessed payload
  end

  module Latest = V1

  module Module_decl = struct
    let name = "user_command"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

type t = Stable.Latest.t [@@deriving sexp, yojson, hash]

let accounts_accessed = Stable.Latest.accounts_accessed

include Comparable.Make (Stable.Latest)

let payload Poly.{payload; _} = payload

let fee = Fn.compose Payload.fee payload

let nonce = Fn.compose Payload.nonce payload

let sender t = Public_key.compress Poly.(t.sender)

let sign (kp : Signature_keypair.t) (payload : Payload.t) : t =
  { payload
  ; sender= kp.public_key
  ; signature= Schnorr.sign kp.private_key payload }

module For_tests = struct
  (* Pretend to sign a command. Much faster than actually signing. *)
  let fake_sign (kp : Signature_keypair.t) (payload : Payload.t) : t =
    { payload
    ; sender= kp.public_key
    ; signature= (kp.private_key, kp.private_key) }
end

module Gen = struct
  let gen_inner (sign' : Signature_lib.Keypair.t -> Payload.t -> t) ~key_gen
      ?(nonce = Account_nonce.zero) ~max_fee create_body =
    let open Quickcheck.Generator.Let_syntax in
    let%bind sender, (receiver : Signature_keypair.t) = key_gen
    and fee = Int.gen_incl 0 max_fee >>| Currency.Fee.of_int
    and memo = String.quickcheck_generator in
    let%map body = create_body receiver in
    let payload : Payload.t =
      Payload.create ~fee ~nonce
        ~memo:(User_command_memo.create_by_digesting_string_exn memo)
        ~body
    in
    sign' sender payload

  let with_random_participants ~keys ~gen =
    let key_gen = Quickcheck_lib.gen_pair @@ Quickcheck_lib.of_array keys in
    gen ~key_gen

  module Payment = struct
    let gen_inner (sign' : Signature_lib.Keypair.t -> Payload.t -> t) ~key_gen
        ?(nonce = Account_nonce.zero) ~max_amount ~max_fee () =
      gen_inner sign' ~key_gen ~nonce ~max_fee
      @@ fun {public_key= receiver; _} ->
      let open Quickcheck.Generator.Let_syntax in
      let%map amount = Int.gen_incl 1 max_amount >>| Currency.Amount.of_int in
      User_command_payload.Body.Payment
        {receiver= Public_key.compress receiver; amount}

    let gen ?(sign_type = `Fake) =
      match sign_type with
      | `Fake ->
          gen_inner For_tests.fake_sign
      | `Real ->
          gen_inner sign

    let gen_with_random_participants ?sign_type ~keys ?nonce ~max_amount
        ~max_fee =
      with_random_participants ~keys ~gen:(fun ~key_gen ->
          gen ?sign_type ~key_gen ?nonce ~max_amount ~max_fee )
  end

  module Stake_delegation = struct
    let gen ~key_gen ?nonce ~max_fee () =
      gen_inner For_tests.fake_sign ~key_gen ?nonce ~max_fee
        (fun {public_key= new_delegate; _} ->
          Quickcheck.Generator.return
          @@ User_command_payload.Body.Stake_delegation
               (Set_delegate {new_delegate= Public_key.compress new_delegate})
      )

    let gen_with_random_participants ~keys ?nonce ~max_fee =
      with_random_participants ~keys ~gen:(gen ?nonce ~max_fee)
  end

  let payment = Payment.gen

  let payment_with_random_participants = Payment.gen_with_random_participants

  let stake_delegation = Stake_delegation.gen

  let stake_delegation_with_random_participants =
    Stake_delegation.gen_with_random_participants
end

module With_valid_signature = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Stable.V1.t
        [@@deriving sexp, eq, bin_io, yojson, version, hash]
      end

      include T
      include Registration.Make_latest_version (T)

      let compare = Stable.V1.compare

      module Gen = Gen
    end

    module Latest = V1

    module Module_decl = struct
      let name = "user_command_with_valid_signature"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest
  include Comparable.Make (Stable.Latest)
end

[%%if
fake_hash]

let check_signature _ = true

[%%else]

let check_signature ({payload; sender; signature} : t) =
  Schnorr.verify signature
    (Snark_params.Tick.Inner_curve.of_affine_coordinates sender)
    payload

[%%endif]

let gen_test =
  let keys = Array.init 2 ~f:(fun _ -> Signature_keypair.create ()) in
  Gen.payment_with_random_participants ~sign_type:`Real ~keys ~max_amount:10000
    ~max_fee:1000 ()

let%test_unit "completeness" =
  Quickcheck.test ~trials:20 gen_test ~f:(fun t -> assert (check_signature t))

let%test_unit "json" =
  Quickcheck.test ~trials:20 ~sexp_of:sexp_of_t gen_test ~f:(fun t ->
      assert (Codable.For_tests.check_encoding (module Stable.Latest) ~equal t)
  )

let check t = Option.some_if (check_signature t) t

let forget_check t = t

let filter_by_participant user_commands public_key =
  List.filter user_commands ~f:(fun user_command ->
      List.mem
        (accounts_accessed user_command)
        public_key ~equal:Public_key.Compressed.equal )
