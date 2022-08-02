module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema

let account_timing () =
  let uint64 = Graphql_basic_scalars.UInt64.typ () in
  let uint32 = Graphql_basic_scalars.UInt32.typ () in
  obj "AccountTiming" ~fields:(fun _ ->
      [ field "initial_mininum_balance" ~typ:uint64
          ~doc:"The initial minimum balance for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Mina_base.Account_timing.Untimed ->
               None
            | Timed timing_info ->
               Some (Currency.Balance.to_uint64 timing_info.initial_minimum_balance)
          )
      ; field "cliff_time" ~typ:uint32
          ~doc:"The cliff time for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Mina_base.Account_timing.Untimed ->
               None
            | Timed timing_info ->
               Some timing_info.cliff_time )
      ; field "cliff_amount" ~typ:uint64
          ~doc:"The cliff amount for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Mina_base.Account_timing.Untimed ->
               None
            | Timed timing_info ->
               Some (Currency.Amount.to_uint64 timing_info.cliff_amount) )
      ; field "vesting_period" ~typ:uint32
          ~doc:"The vesting period for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Mina_base.Account_timing.Untimed ->
               None
            | Timed timing_info ->
               Some timing_info.vesting_period )
      ; field "vesting_increment" ~typ:uint64
          ~doc:"The vesting increment for a time-locked account"
          ~args:Arg.[]
          ~resolve:(fun _ timing ->
            match timing with
            | Mina_base.Account_timing.Untimed ->
               None
            | Timed timing_info ->
               Some (Currency.Amount.to_uint64 timing_info.vesting_increment)
          )
    ] )
