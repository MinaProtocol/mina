open Core
open Currency
open Signature_lib
module Global_slot = Coda_numbers.Global_slot

module type Ledger_intf = sig
  type t

  type location

  val get : t -> location -> Account.t option

  val location_of_key : t -> Account.key -> location option

  val set : t -> location -> Account.t -> unit

  val get_or_create :
    t -> Account.key -> [`Added | `Existed] * Account.t * location

  val get_or_create_account_exn :
    t -> Account.key -> Account.t -> [`Added | `Existed] * location

  val remove_accounts_exn : t -> Account.key list -> unit

  val merkle_root : t -> Ledger_hash.t

  val with_ledger : f:(t -> 'a) -> 'a
end

module Undo = struct
  module UC = User_command

  module User_command_undo = struct
    module Common = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t =
            { user_command: User_command.Stable.V1.t
            ; previous_receipt_chain_hash: Receipt.Chain_hash.Stable.V1.t }
          [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t =
        { user_command: User_command.t
        ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
      [@@deriving sexp]
    end

    module Body = struct
      [%%versioned
      module Stable = struct
        module V1 = struct
          type t =
            | Payment of
                { previous_empty_accounts:
                    Public_key.Compressed.Stable.V1.t list }
            | Stake_delegation of
                { previous_delegate: Public_key.Compressed.Stable.V1.t }
          [@@deriving sexp]

          let to_latest = Fn.id
        end
      end]

      type t = Stable.Latest.t =
        | Payment of {previous_empty_accounts: Public_key.Compressed.t list}
        | Stake_delegation of {previous_delegate: Public_key.Compressed.t}
      [@@deriving sexp]
    end

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = {common: Common.Stable.V1.t; body: Body.Stable.V1.t}
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    (* bin_io omitted *)
    type t = Stable.Latest.t = {common: Common.t; body: Body.t}
    [@@deriving sexp]
  end

  module Fee_transfer_undo = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { fee_transfer: Fee_transfer.Stable.V1.t
          ; previous_empty_accounts: Public_key.Compressed.Stable.V1.t list }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t =
      { fee_transfer: Fee_transfer.t
      ; previous_empty_accounts: Public_key.Compressed.t list }
    [@@deriving sexp]
  end

  module Coinbase_undo = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { coinbase: Coinbase.Stable.V1.t
          ; previous_empty_accounts: Public_key.Compressed.Stable.V1.t list }
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    (* bin_io omitted *)
    type t = Stable.Latest.t =
      { coinbase: Coinbase.t
      ; previous_empty_accounts: Public_key.Compressed.t list }
    [@@deriving sexp]
  end

  module Varying = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          | User_command of User_command_undo.Stable.V1.t
          | Fee_transfer of Fee_transfer_undo.Stable.V1.t
          | Coinbase of Coinbase_undo.Stable.V1.t
        [@@deriving sexp]

        let to_latest = Fn.id
      end
    end]

    (* bin_io omitted *)
    type t = Stable.Latest.t =
      | User_command of User_command_undo.t
      | Fee_transfer of Fee_transfer_undo.t
      | Coinbase of Coinbase_undo.t
    [@@deriving sexp]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        {previous_hash: Ledger_hash.Stable.V1.t; varying: Varying.Stable.V1.t}
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  (* bin_io omitted *)
  type t = Stable.Latest.t = {previous_hash: Ledger_hash.t; varying: Varying.t}
  [@@deriving sexp]
end

module type S = sig
  type ledger

  module Undo : sig
    module User_command_undo : sig
      module Common : sig
        type t = Undo.User_command_undo.Common.t =
          { user_command: User_command.t
          ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
        [@@deriving sexp]
      end

      module Body : sig
        type t = Undo.User_command_undo.Body.t =
          | Payment of {previous_empty_accounts: Public_key.Compressed.t list}
          | Stake_delegation of {previous_delegate: Public_key.Compressed.t}
        [@@deriving sexp]
      end

      type t = Undo.User_command_undo.t = {common: Common.t; body: Body.t}
      [@@deriving sexp]
    end

    module Fee_transfer_undo : sig
      type t = Undo.Fee_transfer_undo.t =
        { fee_transfer: Fee_transfer.t
        ; previous_empty_accounts: Public_key.Compressed.t list }
      [@@deriving sexp]
    end

    module Coinbase_undo : sig
      type t = Undo.Coinbase_undo.t =
        { coinbase: Coinbase.t
        ; previous_empty_accounts: Public_key.Compressed.t list }
      [@@deriving sexp]
    end

    module Varying : sig
      type t = Undo.Varying.t =
        | User_command of User_command_undo.t
        | Fee_transfer of Fee_transfer_undo.t
        | Coinbase of Coinbase_undo.t
      [@@deriving sexp]
    end

    type t = Undo.t = {previous_hash: Ledger_hash.t; varying: Varying.t}
    [@@deriving sexp]

    val transaction : t -> Transaction.t Or_error.t
  end

  val apply_user_command :
       ledger
    -> User_command.With_valid_signature.t
    -> Undo.User_command_undo.t Or_error.t

  val apply_transaction : ledger -> Transaction.t -> Undo.t Or_error.t

  val merkle_root_after_user_command_exn :
    ledger -> User_command.With_valid_signature.t -> Ledger_hash.t

  val undo : ledger -> Undo.t -> unit Or_error.t

  module For_tests : sig
    val validate_timing :
         account:Account.t
      -> txn_amount:Amount.t
      -> txn_global_slot:Global_slot.t
      -> Account.Timing.t Or_error.t
  end
end

module Make (L : Ledger_intf) : S with type ledger := L.t = struct
  open L

  let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

  let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

  let get' ledger tag location =
    error_opt (sprintf "%s account not found" tag) (get ledger location)

  let location_of_key' ledger tag key =
    error_opt
      (sprintf "%s location not found" tag)
      (location_of_key ledger key)

  let add_amount balance amount =
    error_opt "overflow" (Balance.add_amount balance amount)

  let sub_amount balance amount =
    error_opt "insufficient funds" (Balance.sub_amount balance amount)

  let sub_account_creation_fee action amount =
    let fee = Coda_compile_config.account_creation_fee in
    if action = `Added then
      error_opt
        (sprintf
           !"Error subtracting account creation fee %{sexp: Currency.Fee.t}; \
             transaction amount %{sexp: Currency.Amount.t} insufficient"
           fee amount)
        Amount.(sub amount (of_fee fee))
    else Ok amount

  let check b =
    ksprintf (fun s -> if b then Ok () else Or_error.error_string s)

  let validate_nonces txn_nonce account_nonce =
    check
      (Account.Nonce.equal account_nonce txn_nonce)
      !"Nonce in account %{sexp: Account.Nonce.t} different from nonce in \
        transaction %{sexp: Account.Nonce.t}"
      account_nonce txn_nonce

  let validate_time ~valid_until ~current_global_slot =
    check
      Global_slot.(current_global_slot <= valid_until)
      !"Current global slot %{sexp: Global_slot.t} greater than transaction \
        expiry slot %{sexp: Global_slot.t}"
      current_global_slot valid_until

  let validate_timing ~account ~txn_amount ~txn_global_slot =
    let open Account.Poly in
    let open Account.Timing.Poly in
    match account.timing with
    | Untimed ->
        (* no time restrictions *)
        Or_error.return Untimed
    | Timed
        {initial_minimum_balance; cliff_time; vesting_period; vesting_increment}
      ->
        let open Or_error.Let_syntax in
        let%map curr_min_balance =
          let account_balance = account.balance in
          let nsf_error () =
            Or_error.errorf
              !"For timed account, the requested transaction for amount \
                %{sexp: Amount.t} at global slot %{sexp: Global_slot.t}, the \
                balance %{sexp: Balance.t} is insufficient"
              txn_amount txn_global_slot account_balance
          in
          let min_balance_error min_balance =
            Or_error.errorf
              !"For timed account, the requested transaction for amount \
                %{sexp: Amount.t} at global slot %{sexp: Global_slot.t}, \
                applying the transaction would put the balance below the \
                calculated minimum balance of %{sexp: Balance.t}"
              txn_amount txn_global_slot min_balance
          in
          match Balance.(account_balance - txn_amount) with
          | None ->
              (* checking for sufficient funds may be redundant with a check elsewhere
               regardless, the transaction would put the account below any calculated minimum balance
               so don't bother with the remaining computations
            *)
              nsf_error ()
          | Some proposed_new_balance ->
              let open Unsigned in
              let curr_min_balance =
                if Global_slot.(txn_global_slot < cliff_time) then
                  initial_minimum_balance
                else
                  (* take advantage of fact that global slots are uint32's *)
                  let num_periods =
                    UInt32.(
                      Infix.((txn_global_slot - cliff_time) / vesting_period)
                      |> to_int64 |> UInt64.of_int64)
                  in
                  let min_balance_decrement =
                    UInt64.Infix.(
                      num_periods * Amount.to_uint64 vesting_increment)
                    |> Amount.of_uint64
                  in
                  match
                    Balance.(initial_minimum_balance - min_balance_decrement)
                  with
                  | None ->
                      Balance.zero
                  | Some amt ->
                      amt
              in
              if Balance.(proposed_new_balance < curr_min_balance) then
                min_balance_error curr_min_balance
              else Or_error.return curr_min_balance
        in
        (* once the calculated minimum balance becomes zero, the account becomes untimed *)
        if Balance.(curr_min_balance > zero) then account.timing else Untimed

  module Undo = struct
    include Undo

    let transaction : t -> Transaction.t Or_error.t =
     fun {varying; _} ->
      match varying with
      | User_command tr ->
          Option.value_map ~default:(Or_error.error_string "Bad signature")
            (UC.check tr.common.user_command) ~f:(fun x ->
              Ok (Transaction.User_command x) )
      | Fee_transfer f ->
          Ok (Fee_transfer f.fee_transfer)
      | Coinbase c ->
          Ok (Coinbase c.coinbase)
  end

  let previous_empty_accounts action pk = if action = `Added then [pk] else []

  (* someday: It would probably be better if we didn't modify the receipt chain hash
  in the case that the sender is equal to the receiver, but it complicates the SNARK, so
  we don't for now. *)
  let apply_user_command_unchecked ledger
      ({payload; sender; signature= _} as user_command : User_command.t) =
    let sender = Public_key.compress sender in
    let nonce = User_command.Payload.nonce payload in
    let open Or_error.Let_syntax in
    let%bind sender_location = location_of_key' ledger "" sender in
    (* We unconditionally deduct the fee if this transaction succeeds *)
    let%bind sender_account, common =
      let%bind account = get' ledger "sender" sender_location in
      let%bind balance =
        sub_amount account.balance
          (Amount.of_fee (User_command.Payload.fee payload))
      in
      let common : Undo.User_command_undo.Common.t =
        {user_command; previous_receipt_chain_hash= account.receipt_chain_hash}
      in
      let%bind () = validate_nonces nonce account.nonce in
      (* TODO: Put actual value here. See issue #4036. *)
      let current_global_slot = Global_slot.zero in
      let%bind () =
        validate_time ~valid_until:payload.common.valid_until
          ~current_global_slot
      in
      let%map timing =
        if User_command.Payload.is_payment payload then
          let txn_amount =
            match User_command.Payload.body payload with
            | Payment {amount; _} ->
                amount
            | _ ->
                failwith "Expected payment when validating transaction timing"
          in
          validate_timing ~txn_amount ~txn_global_slot:current_global_slot
            ~account
        else return account.timing
      in
      let account =
        { account with
          nonce= Account.Nonce.succ account.nonce
        ; receipt_chain_hash=
            Receipt.Chain_hash.cons payload account.receipt_chain_hash
        ; timing }
      in
      ({account with balance}, common)
    in
    match User_command.Payload.body payload with
    | Stake_delegation (Set_delegate {new_delegate}) ->
        set ledger sender_location {sender_account with delegate= new_delegate} ;
        return
          { Undo.User_command_undo.common
          ; body= Stake_delegation {previous_delegate= sender_account.delegate}
          }
    | Payment Payment_payload.Poly.{amount; receiver} ->
        let%bind sender_balance' = sub_amount sender_account.balance amount in
        let undo emptys : Undo.User_command_undo.t =
          {common; body= Payment {previous_empty_accounts= emptys}}
        in
        if Public_key.Compressed.equal sender receiver then (
          ignore @@ set ledger sender_location sender_account ;
          return (undo []) )
        else
          let action, receiver_account, receiver_location =
            get_or_create ledger receiver
          in
          let previous_empty_accounts =
            previous_empty_accounts action receiver
          in
          let%map receiver_balance' =
            (*deduct the account creation fee*)
            let%bind amount' = sub_account_creation_fee action amount in
            add_amount receiver_account.balance amount'
          in
          set ledger sender_location
            {sender_account with balance= sender_balance'} ;
          set ledger receiver_location
            {receiver_account with balance= receiver_balance'} ;
          undo previous_empty_accounts

  let apply_user_command ledger
      (user_command : User_command.With_valid_signature.t) =
    apply_user_command_unchecked ledger (user_command :> User_command.t)

  let process_fee_transfer t (transfer : Fee_transfer.t) ~modify_balance =
    let open Or_error.Let_syntax in
    match transfer with
    | `One (pk, fee) ->
        let action, a, loc = get_or_create t pk in
        let emptys = previous_empty_accounts action pk in
        let%map balance = modify_balance action pk a.balance fee in
        set t loc {a with balance} ;
        emptys
    | `Two ((pk1, fee1), (pk2, fee2)) ->
        let action1, a1, l1 = get_or_create t pk1 in
        let emptys1 = previous_empty_accounts action1 pk1 in
        if Public_key.Compressed.equal pk1 pk2 then (
          let%bind fee = error_opt "overflow" (Fee.add fee1 fee2) in
          let%map balance = modify_balance action1 pk1 a1.balance fee in
          set t l1 {a1 with balance} ;
          emptys1 )
        else
          let action2, a2, l2 = get_or_create t pk2 in
          let emptys2 = previous_empty_accounts action2 pk2 in
          let%bind balance1 = modify_balance action1 pk1 a1.balance fee1 in
          let%map balance2 = modify_balance action2 pk1 a2.balance fee2 in
          set t l1 {a1 with balance= balance1} ;
          set t l2 {a2 with balance= balance2} ;
          emptys1 @ emptys2

  let apply_fee_transfer t transfer =
    let open Or_error.Let_syntax in
    let%map previous_empty_accounts =
      process_fee_transfer t transfer ~modify_balance:(fun action _ b f ->
          let%bind amount =
            let amount = Amount.of_fee f in
            sub_account_creation_fee action amount
          in
          add_amount b amount )
    in
    Undo.Fee_transfer_undo.{fee_transfer= transfer; previous_empty_accounts}

  let undo_fee_transfer t
      ({previous_empty_accounts; fee_transfer} : Undo.Fee_transfer_undo.t) =
    let open Or_error.Let_syntax in
    let%map _ =
      process_fee_transfer t fee_transfer ~modify_balance:(fun _ pk b f ->
          let action =
            if List.mem ~equal:Account.equal_key previous_empty_accounts pk
            then `Added
            else `Existed
          in
          let%bind amount =
            sub_account_creation_fee action (Amount.of_fee f)
          in
          sub_amount b amount )
    in
    remove_accounts_exn t previous_empty_accounts

  let apply_coinbase t
      (* TODO: Better system needed for making atomic changes. Could use a monad. *)
      ({receiver; fee_transfer; amount= coinbase_amount} as cb : Coinbase.t) =
    let open Or_error.Let_syntax in
    let%bind receiver_reward, emptys1, transferee_update =
      match fee_transfer with
      | None ->
          return (coinbase_amount, [], None)
      | Some (transferee, fee) ->
          assert (not @@ Public_key.Compressed.equal transferee receiver) ;
          let fee = Amount.of_fee fee in
          let%bind receiver_reward =
            error_opt "Coinbase fee transfer too large"
              (Amount.sub coinbase_amount fee)
          in
          let action, transferee_account, transferee_location =
            get_or_create t transferee
          in
          let emptys = previous_empty_accounts action transferee in
          let%map balance =
            let%bind amount = sub_account_creation_fee action fee in
            add_amount transferee_account.balance amount
          in
          ( receiver_reward
          , emptys
          , Some (transferee_location, {transferee_account with balance}) )
    in
    let action2, receiver_account, receiver_location =
      get_or_create t receiver
    in
    let emptys2 = previous_empty_accounts action2 receiver in
    let%map receiver_balance =
      let%bind amount = sub_account_creation_fee action2 receiver_reward in
      add_amount receiver_account.balance amount
    in
    set t receiver_location {receiver_account with balance= receiver_balance} ;
    Option.iter transferee_update ~f:(fun (l, a) -> set t l a) ;
    Undo.Coinbase_undo.
      {coinbase= cb; previous_empty_accounts= emptys1 @ emptys2}

  (* Don't have to be atomic here because these should never fail. In fact, none of
  the undo functions should ever return an error. This should be fixed in the types. *)
  let undo_coinbase t
      Undo.Coinbase_undo.
        { coinbase= {receiver; fee_transfer; amount= coinbase_amount}
        ; previous_empty_accounts } =
    let receiver_reward =
      match fee_transfer with
      | None ->
          coinbase_amount
      | Some (transferee, fee) ->
          let fee = Amount.of_fee fee in
          let transferee_location =
            Or_error.ok_exn (location_of_key' t "transferee" transferee)
          in
          let transferee_account =
            Or_error.ok_exn (get' t "transferee" transferee_location)
          in
          let transferee_balance =
            let action =
              if
                List.mem previous_empty_accounts transferee
                  ~equal:Account.equal_key
              then `Added
              else `Existed
            in
            let amount =
              sub_account_creation_fee action fee |> Or_error.ok_exn
            in
            Option.value_exn
              (Balance.sub_amount transferee_account.balance amount)
          in
          set t transferee_location
            {transferee_account with balance= transferee_balance} ;
          Option.value_exn (Amount.sub coinbase_amount fee)
    in
    let receiver_location =
      Or_error.ok_exn (location_of_key' t "receiver" receiver)
    in
    let receiver_account =
      Or_error.ok_exn (get' t "receiver" receiver_location)
    in
    let receiver_balance =
      let action =
        if List.mem previous_empty_accounts receiver ~equal:Account.equal_key
        then `Added
        else `Existed
      in
      let amount =
        sub_account_creation_fee action receiver_reward |> Or_error.ok_exn
      in
      Option.value_exn (Balance.sub_amount receiver_account.balance amount)
    in
    set t receiver_location {receiver_account with balance= receiver_balance} ;
    remove_accounts_exn t previous_empty_accounts

  let undo_user_command ledger
      { Undo.User_command_undo.common=
          { user_command= {payload; sender; signature= _}
          ; previous_receipt_chain_hash }
      ; body } =
    let sender = Public_key.compress sender in
    let nonce = User_command.Payload.nonce payload in
    let open Or_error.Let_syntax in
    let%bind sender_location = location_of_key' ledger "sender" sender in
    let%bind sender_account =
      let%bind account = get' ledger "sender" sender_location in
      let%bind balance =
        add_amount account.balance
          (Amount.of_fee (User_command.Payload.fee payload))
      in
      let%bind () = validate_nonces (Account.Nonce.succ nonce) account.nonce in
      return
        { account with
          balance
        ; nonce
        ; receipt_chain_hash= previous_receipt_chain_hash }
    in
    match (User_command.Payload.body payload, body) with
    | Stake_delegation (Set_delegate _), Stake_delegation {previous_delegate}
      ->
        set ledger sender_location
          {sender_account with delegate= previous_delegate} ;
        return ()
    | Payment {amount; receiver}, Payment {previous_empty_accounts} ->
        let%bind sender_balance' = add_amount sender_account.balance amount in
        if Public_key.Compressed.equal sender receiver then (
          set ledger sender_location sender_account ;
          return () )
        else
          let%bind receiver_location =
            location_of_key' ledger "receiver" receiver
          in
          let%bind receiver_account =
            get' ledger "receiver" receiver_location
          in
          let%map receiver_balance' =
            let action =
              if
                List.mem previous_empty_accounts receiver
                  ~equal:Account.equal_key
              then `Added
              else `Existed
            in
            let%bind amount' = sub_account_creation_fee action amount in
            sub_amount receiver_account.balance amount'
          in
          set ledger sender_location
            {sender_account with balance= sender_balance'} ;
          set ledger receiver_location
            {receiver_account with balance= receiver_balance'} ;
          remove_accounts_exn ledger previous_empty_accounts
    | _, _ ->
        failwith "Undo/command mismatch"

  let undo : t -> Undo.t -> unit Or_error.t =
   fun ledger undo ->
    let open Or_error.Let_syntax in
    let%map res =
      match undo.varying with
      | Fee_transfer u ->
          undo_fee_transfer ledger u
      | User_command u ->
          undo_user_command ledger u
      | Coinbase c ->
          undo_coinbase ledger c ; Ok ()
    in
    Debug_assert.debug_assert (fun () ->
        [%test_eq: Ledger_hash.t] undo.previous_hash (merkle_root ledger) ) ;
    res

  let apply_transaction ledger (t : Transaction.t) =
    O1trace.measure "apply_transaction" (fun () ->
        let previous_hash = merkle_root ledger in
        Or_error.map
          ( match t with
          | User_command txn ->
              Or_error.map (apply_user_command ledger txn) ~f:(fun u ->
                  Undo.Varying.User_command u )
          | Fee_transfer t ->
              Or_error.map (apply_fee_transfer ledger t) ~f:(fun u ->
                  Undo.Varying.Fee_transfer u )
          | Coinbase t ->
              Or_error.map (apply_coinbase ledger t) ~f:(fun u ->
                  Undo.Varying.Coinbase u ) )
          ~f:(fun varying -> {Undo.previous_hash; varying}) )

  let merkle_root_after_user_command_exn ledger payment =
    let undo = Or_error.ok_exn (apply_user_command ledger payment) in
    let root = merkle_root ledger in
    Or_error.ok_exn (undo_user_command ledger undo) ;
    root

  module For_tests = struct
    let validate_timing = validate_timing
  end
end
