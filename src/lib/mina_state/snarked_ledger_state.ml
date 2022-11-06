open Core
open Mina_base
open Snark_params
module Global_slot = Mina_numbers.Global_slot
open Currency

let top_hash_logging_enabled = ref false

module Pending_coinbase_stack_state = struct
  module Init_stack = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Base of Pending_coinbase.Stack_versioned.Stable.V1.t | Merge
        [@@deriving sexp, hash, compare, equal, yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'pending_coinbase t =
          { source : 'pending_coinbase; target : 'pending_coinbase }
        [@@deriving sexp, hash, compare, equal, fields, yojson, hlist]

        let to_latest pending_coinbase { source; target } =
          { source = pending_coinbase source; target = pending_coinbase target }
      end
    end]

    let typ pending_coinbase =
      Tick.Typ.of_hlistable
        [ pending_coinbase; pending_coinbase ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  type 'pending_coinbase poly = 'pending_coinbase Poly.t =
    { source : 'pending_coinbase; target : 'pending_coinbase }
  [@@deriving sexp, hash, compare, equal, fields, yojson]

  (* State of the coinbase stack for the current transaction snark *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Pending_coinbase.Stack_versioned.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, hash, compare, equal, yojson]

      let to_latest = Fn.id
    end
  end]

  type var = Pending_coinbase.Stack.var Poly.t

  let typ = Poly.typ Pending_coinbase.Stack.typ

  let to_input ({ source; target } : t) =
    Random_oracle.Input.Chunked.append
      (Pending_coinbase.Stack.to_input source)
      (Pending_coinbase.Stack.to_input target)

  let var_to_input ({ source; target } : var) =
    Random_oracle.Input.Chunked.append
      (Pending_coinbase.Stack.var_to_input source)
      (Pending_coinbase.Stack.var_to_input target)

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

module T = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type ( 'ledger_hash
             , 'amount
             , 'pending_coinbase
             , 'fee_excess
             , 'sok_digest
             , 'local_state )
             t =
          { source :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state )
              Registers.Stable.V1.t
          ; target :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state )
              Registers.Stable.V1.t
          ; connecting_ledger_left : 'ledger_hash
          ; connecting_ledger_right : 'ledger_hash
          ; supply_increase : 'amount
          ; fee_excess : 'fee_excess
          ; sok_digest : 'sok_digest
          }
        [@@deriving compare, equal, hash, sexp, yojson, hlist]
      end
    end]

    let with_empty_local_state ~supply_increase ~fee_excess ~sok_digest
        ~source_first_pass_ledger ~target_first_pass_ledger
        ~source_second_pass_ledger ~target_second_pass_ledger
        ~connecting_ledger_left ~connecting_ledger_right
        ~pending_coinbase_stack_state : _ t =
      { supply_increase
      ; fee_excess
      ; sok_digest
      ; connecting_ledger_left
      ; connecting_ledger_right
      ; source =
          { first_pass_ledger = source_first_pass_ledger
          ; second_pass_ledger = source_second_pass_ledger
          ; pending_coinbase_stack =
              pending_coinbase_stack_state.Pending_coinbase_stack_state.source
          ; local_state = Local_state.empty ()
          }
      ; target =
          { first_pass_ledger = target_first_pass_ledger
          ; second_pass_ledger = target_second_pass_ledger
          ; pending_coinbase_stack = pending_coinbase_stack_state.target
          ; local_state = Local_state.empty ()
          }
      }

    let typ ledger_hash amount pending_coinbase fee_excess sok_digest
        local_state_typ =
      let registers =
        let open Registers in
        Tick.Typ.of_hlistable
          [ ledger_hash; ledger_hash; pending_coinbase; local_state_typ ]
          ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
          ~value_of_hlist:of_hlist
      in
      Tick.Typ.of_hlistable
        [ registers
        ; registers
        ; ledger_hash
        ; ledger_hash
        ; amount
        ; fee_excess
        ; sok_digest
        ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  type ( 'ledger_hash
       , 'amount
       , 'pending_coinbase
       , 'fee_excess
       , 'sok_digest
       , 'local_state )
       poly =
        ( 'ledger_hash
        , 'amount
        , 'pending_coinbase
        , 'fee_excess
        , 'sok_digest
        , 'local_state )
        Poly.t =
    { source : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
    ; target : ('ledger_hash, 'pending_coinbase, 'local_state) Registers.t
    ; connecting_ledger_left : 'ledger_hash
    ; connecting_ledger_right : 'ledger_hash
    ; supply_increase : 'amount
    ; fee_excess : 'fee_excess
    ; sok_digest : 'sok_digest
    }
  [@@deriving compare, equal, hash, sexp, yojson]

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        ( Frozen_ledger_hash.Stable.V1.t
        , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
        , Pending_coinbase.Stack_versioned.Stable.V1.t
        , Fee_excess.Stable.V1.t
        , unit
        , Local_state.Stable.V1.t )
        Poly.Stable.V2.t
      [@@deriving compare, equal, hash, sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  module With_sok = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          ( Frozen_ledger_hash.Stable.V1.t
          , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
          , Pending_coinbase.Stack_versioned.Stable.V1.t
          , Fee_excess.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t
          , Local_state.Stable.V1.t )
          Poly.Stable.V2.t
        [@@deriving compare, equal, hash, sexp, yojson]

        let to_latest = Fn.id
      end
    end]

    type var =
      ( Frozen_ledger_hash.var
      , Currency.Amount.Signed.var
      , Pending_coinbase.Stack.var
      , Fee_excess.var
      , Sok_message.Digest.Checked.t
      , Local_state.Checked.t )
      Poly.t

    let typ : (var, t) Tick.Typ.t =
      Poly.typ Frozen_ledger_hash.typ Currency.Amount.Signed.typ
        Pending_coinbase.Stack.typ Fee_excess.typ Sok_message.Digest.typ
        Local_state.typ

    let to_input
        { source
        ; target
        ; connecting_ledger_left
        ; connecting_ledger_right
        ; supply_increase
        ; fee_excess
        ; sok_digest
        } =
      let input =
        Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
          [| Sok_message.Digest.to_input sok_digest
           ; Registers.to_input source
           ; Registers.to_input target
           ; Frozen_ledger_hash.to_input connecting_ledger_left
           ; Frozen_ledger_hash.to_input connecting_ledger_right
           ; Amount.Signed.to_input supply_increase
           ; Fee_excess.to_input fee_excess
          |]
      in
      if !top_hash_logging_enabled then
        Format.eprintf
          !"Generating unchecked top hash from:@.%{sexp: Tick.Field.t \
            Random_oracle.Input.Chunked.t}@."
          input ;
      input

    let to_field_elements t = Random_oracle.pack_input (to_input t)

    module Checked = struct
      type t = var

      let to_input
          { source
          ; target
          ; connecting_ledger_left
          ; connecting_ledger_right
          ; supply_increase
          ; fee_excess
          ; sok_digest
          } =
        let open Tick in
        let open Checked.Let_syntax in
        let%bind fee_excess = Fee_excess.to_input_checked fee_excess in
        let source = Registers.Checked.to_input source
        and target = Registers.Checked.to_input target in
        let%bind supply_increase =
          Amount.Signed.Checked.to_input supply_increase
        in
        let input =
          Array.reduce_exn ~f:Random_oracle.Input.Chunked.append
            [| Sok_message.Digest.Checked.to_input sok_digest
             ; source
             ; target
             ; Frozen_ledger_hash.var_to_input connecting_ledger_left
             ; Frozen_ledger_hash.var_to_input connecting_ledger_right
             ; supply_increase
             ; fee_excess
            |]
        in
        let%map () =
          as_prover
            As_prover.(
              if !top_hash_logging_enabled then
                let%map input = Random_oracle.read_typ' input in
                Format.eprintf
                  !"Generating checked top hash from:@.%{sexp: Field.t \
                    Random_oracle.Input.Chunked.t}@."
                  input
              else return ())
        in
        input

      let to_field_elements t =
        let open Tick.Checked.Let_syntax in
        Tick.Run.run_checked (to_input t >>| Random_oracle.Checked.pack_input)
    end
  end

  let option lab =
    Option.value_map ~default:(Or_error.error_string lab) ~f:(fun x -> Ok x)

  let merge (s1 : _ Poly.t) (s2 : _ Poly.t) =
    let open Or_error.Let_syntax in
    let registers_check_equal (t1 : _ Registers.t) (t2 : _ Registers.t) =
      let check' k f =
        let x1 = Field.get f t1 and x2 = Field.get f t2 in
        k x1 x2
      in
      let module S = struct
        module type S = sig
          type t [@@deriving eq, sexp_of]
        end
      end in
      let check (type t) (module T : S.S with type t = t) f =
        let open T in
        check'
          (fun x1 x2 ->
            if equal x1 x2 then return ()
            else
              Or_error.errorf
                !"%s is inconsistent between transitions (%{sexp: t} vs \
                  %{sexp: t})"
                (Field.name f) x1 x2 )
          f
      in
      let module PC = struct
        type t = Pending_coinbase.Stack.t [@@deriving sexp_of]

        let equal t1 t2 =
          Pending_coinbase.Stack.connected ~first:t1 ~second:t2 ()
      end in
      Registers.Fields.to_list
        ~first_pass_ledger:(check (module Ledger_hash))
        ~second_pass_ledger:(check (module Ledger_hash))
        ~pending_coinbase_stack:(check (module PC))
        ~local_state:(check (module Local_state))
      |> Or_error.combine_errors_unit
    in
    let connecting_ledger_left = failwith "TODO merge rule" in
    let connecting_ledger_right = failwith "TODO merge rule" in
    let%map fee_excess = Fee_excess.combine s1.fee_excess s2.fee_excess
    and supply_increase =
      Currency.Amount.Signed.add s1.supply_increase s2.supply_increase
      |> option "Error adding supply_increase"
    and () = registers_check_equal s1.target s2.source in
    ( { source = s1.source
      ; target = s2.target
      ; connecting_ledger_left
      ; connecting_ledger_right
      ; fee_excess
      ; supply_increase
      ; sok_digest = ()
      }
      : t )

  include Hashable.Make_binable (Stable.Latest)
  include Comparable.Make (Stable.Latest)

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map source = Registers.gen
    and target = Registers.gen
    and connecting_ledger_left = Frozen_ledger_hash.gen
    and connecting_ledger_right = Frozen_ledger_hash.gen
    and fee_excess = Fee_excess.gen
    and supply_increase = Currency.Amount.Signed.gen in
    ( { source
      ; target
      ; connecting_ledger_left
      ; connecting_ledger_right
      ; fee_excess
      ; supply_increase
      ; sok_digest = ()
      }
      : t )
end

include T
