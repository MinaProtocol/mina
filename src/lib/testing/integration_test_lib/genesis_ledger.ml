open Core
open Currency
open Signature_lib

let runtime_timing_of_timing = function
  | Mina_base.Account.Timing.Untimed ->
      None
  | Timed t ->
      Some
        { Runtime_config.Accounts.Single.Timed.initial_minimum_balance =
            t.initial_minimum_balance
        ; cliff_time = t.cliff_time
        ; cliff_amount = t.cliff_amount
        ; vesting_period = t.vesting_period
        ; vesting_increment = t.vesting_increment
        }

type t =
  { accounts : (string * Runtime_config.Accounts.single) list
  ; keypairs :
      (Network_keypair.t Core.String.Map.t
      [@to_yojson
        fun map ->
          `Assoc
            (Core.Map.fold_right ~init:[]
               ~f:(fun ~key:k ~data:v accum ->
                 (k, Network_keypair.to_yojson v) :: accum )
               map )] )
  }

let create (config : Test_config.Test_account.t list) =
  let key_names_list = List.map config ~f:(fun acct -> acct.account_name) in
  if List.contains_dup ~compare:String.compare key_names_list then
    failwith
      "All accounts in genesis ledger must have unique names.  Check to make \
       sure you are not using the same account_name more than once" ;
  let keypairs =
    List.take
      (* the first keypair is the genesis winner and is assumed to be untimed.
         Therefore dropping it, and not assigning it to any block producer *)
      (List.tl_exn
         (Array.to_list (Lazy.force Key_gen.Sample_keypairs.keypairs)) )
      (List.length config)
  in
  let add_accounts accounts_and_keypairs =
    List.map accounts_and_keypairs
      ~f:(fun
           ( { Test_config.Test_account.balance
             ; account_name
             ; timing
             ; permissions
             ; zkapp
             }
           , (pk, sk) )
         ->
        let timing = runtime_timing_of_timing timing in
        let default = Runtime_config.Accounts.Single.default in
        let account =
          { default with
            pk = Public_key.Compressed.to_string pk
          ; sk = Some (Private_key.to_base58_check sk)
          ; balance =
              Balance.of_mina_string_exn balance
              (* delegation currently unsupported *)
          ; delegate = None
          ; timing
          ; permissions =
              Option.map
                ~f:Runtime_config.Accounts.Single.Permissions.of_permissions
                permissions
          ; zkapp =
              Option.map
                ~f:Runtime_config.Accounts.Single.Zkapp_account.of_zkapp zkapp
          }
        in
        (account_name, account) )
  in
  let genesis_accounts_and_keys = List.zip_exn config keypairs in
  let mk_net_keypair keypair_name (pk, sk) =
    let keypair =
      { Keypair.public_key = Public_key.decompress_exn pk; private_key = sk }
    in
    Network_keypair.create_network_keypair ~keypair_name ~keypair
  in
  let genesis_keypairs =
    List.fold genesis_accounts_and_keys ~init:String.Map.empty
      ~f:(fun map ({ account_name; _ }, (pk, sk)) ->
        let keypair = mk_net_keypair account_name (pk, sk) in
        String.Map.add_exn map ~key:account_name ~data:keypair )
  in
  let genesis_ledger_accounts = add_accounts genesis_accounts_and_keys in
  { accounts = genesis_ledger_accounts; keypairs = genesis_keypairs }
