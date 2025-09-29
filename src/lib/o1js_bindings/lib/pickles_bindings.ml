open Core_kernel
module Js = Js_of_ocaml.Js
module Impl = Pickles.Impls.Step
module Field = Impl.Field
module Boolean = Impl.Boolean
module Typ = Impl.Typ
module Backend = Pickles.Backend

module Public_input = struct
  type t = Field.t array

  module Constant = struct
    type t = Field.Constant.t array
  end
end

type 'a statement = 'a array * 'a array

module Statement = struct
  type t = Field.t statement

  module Constant = struct
    type t = Field.Constant.t statement
  end
end

let public_input_typ (i : int) = Typ.array ~length:i Field.typ

let statement_typ (input_size : int) (output_size : int) =
  Typ.(array ~length:input_size Field.typ * array ~length:output_size Field.typ)

type 'proof js_prover =
     Public_input.Constant.t
  -> (Public_input.Constant.t * 'proof) Promise_js_helpers.js_promise

let dummy_constraints =
  let module Inner_curve = Kimchi_pasta.Pasta.Pallas in
  let module Step_main_inputs = Pickles.Step_main_inputs in
  let inner_curve_typ : (Field.t * Field.t, Inner_curve.t) Typ.t =
    Typ.transport Step_main_inputs.Inner_curve.typ
      ~there:Inner_curve.to_affine_exn ~back:Inner_curve.of_affine
  in
  fun () ->
    let x =
      Impl.exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
    in
    let g = Impl.exists inner_curve_typ ~compute:(fun _ -> Inner_curve.one) in
    ignore
      ( Pickles.Scalar_challenge.to_field_checked'
          (module Impl)
          ~num_bits:16
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t * Field.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Pickles.Step_verifier.Scalar_challenge.endo g ~num_bits:4
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t )

(* what we use in places where we don't care about the generic type parameter *)
type proof = Pickles_types.Nat.N0.n Pickles.Proof.t

let unsafe_coerce_proof (proof : proof) : 'm Pickles.Proof.t = Obj.magic proof

type pickles_rule_js_return =
  < publicOutput : Public_input.t Js.prop
  ; previousStatements : Statement.t array Js.prop
  ; previousProofs : proof array Js.prop
  ; shouldVerify : Boolean.var array Js.prop >
  Js.t

type pickles_rule_js =
  < identifier : Js.js_string Js.t Js.prop
  ; main :
      (Public_input.t -> pickles_rule_js_return Promise_js_helpers.js_promise)
      Js.prop
  ; featureFlags : bool option Pickles_types.Plonk_types.Features.t Js.prop
  ; proofsToVerify :
      < isSelf : bool Js.t Js.prop ; tag : Js.Unsafe.any Js.t Js.prop > Js.t
      array
      Js.prop >
  Js.t

let map_feature_flags_option
    (feature_flags_ : bool option Pickles_types.Plonk_types.Features.t) =
  Pickles_types.Plonk_types.Features.map feature_flags_ ~f:(function
    | Some true ->
        Pickles_types.Opt.Flag.Yes
    | Some false ->
        Pickles_types.Opt.Flag.No
    | None ->
        Pickles_types.Opt.Flag.Maybe )

module Choices = struct
  open Pickles_types
  open Hlist

  module Tag = struct
    type ('var, 'value, 'width) t =
      | Tag :
          ('var, 'value, 'width, 'height) Pickles.Tag.t
          -> ('var, 'value, 'width) t
  end

  module Prevs = struct
    type ('var, 'value, 'width, 'height) t =
      | Prevs :
          (   self:('var, 'value, 'width) Tag.t
           -> ('prev_var, 'prev_values, 'widths, 'heights) H4.T(Pickles.Tag).t
          )
          -> ('var, 'value, 'width, 'height) t

    let of_rule (rule : pickles_rule_js) =
      let js_prevs = rule##.proofsToVerify in
      let rec get_tags (Prevs prevs) index =
        if index < 0 then Prevs prevs
        else
          let js_tag = Array.get js_prevs index in
          (* We introduce new opaque types to make sure that the type in the tag
             doesn't escape into the environment or have other ill effects.
          *)
          let module Types = struct
            type var

            type value

            type width

            type height
          end in
          let open Types in
          let to_tag ~self tag : (var, value, width, height) Pickles.Tag.t =
            let (Tag.Tag self) = self in
            (* The magic here isn't ideal, but it's safe enough if we immediately
               hide it behind [Types].
            *)
            if Js.to_bool tag##.isSelf then Obj.magic self
            else Obj.magic tag##.tag
          in
          let tag = to_tag js_tag in
          let prevs ~self : _ H4.T(Pickles.Tag).t = tag ~self :: prevs ~self in
          get_tags (Prevs prevs) (index - 1)
      in
      get_tags (Prevs (fun ~self:_ -> [])) (Array.length js_prevs - 1)
  end

  module Inductive_rule = struct
    type ( 'var
         , 'value
         , 'width
         , 'height
         , 'arg_var
         , 'arg_value
         , 'ret_var
         , 'ret_value
         , 'auxiliary_var
         , 'auxiliary_value )
         t =
      | Rule :
          (   self:('var, 'value, 'width) Tag.t
           -> ( 'prev_vars
              , 'prev_values
              , 'widths
              , 'heights
              , 'arg_var
              , 'arg_value
              , 'ret_var
              , 'ret_value
              , 'auxiliary_var
              , 'auxiliary_value )
              Pickles.Inductive_rule.Promise.t )
          -> ( 'var
             , 'value
             , 'width
             , 'height
             , 'arg_var
             , 'arg_value
             , 'ret_var
             , 'ret_value
             , 'auxiliary_var
             , 'auxiliary_value )
             t

    let rec should_verifys :
        type prev_vars prev_values widths heights.
           int
        -> (prev_vars, prev_values, widths, heights) H4.T(Pickles.Tag).t
        -> Boolean.var array
        -> prev_vars H1.T(E01(Pickles.Inductive_rule.B)).t =
     fun index tags should_verifys_js ->
      match tags with
      | [] ->
          []
      | _ :: tags ->
          let js_bool = Array.get should_verifys_js index in
          let should_verifys =
            should_verifys (index + 1) tags should_verifys_js
          in
          js_bool :: should_verifys

    let should_verifys tags should_verifys_js =
      should_verifys 0 tags should_verifys_js

    let get_typ ~public_input_size ~public_output_size
        (type a1 a2 a3 a4 width height) (tag : (a1, a2, a3, a4) Pickles.Tag.t)
        (self :
          ( Public_input.t * Public_input.t
          , Public_input.Constant.t * Public_input.Constant.t
          , width
          , height )
          Pickles.Tag.t ) =
      match Type_equal.Id.same_witness tag.id self.id with
      | None ->
          Pickles.Types_map.public_input tag
      | Some T ->
          statement_typ public_input_size public_output_size

    let rec prev_statements :
        type prev_vars prev_values widths heights width height.
           public_input_size:int
        -> public_output_size:int
        -> self:
             ( Public_input.t * Public_input.t
             , Public_input.Constant.t * Public_input.Constant.t
             , width
             , height )
             Pickles.Tag.t
        -> int
        -> (prev_vars, prev_values, widths, heights) H4.T(Pickles.Tag).t
        -> Statement.t array
        -> prev_vars H1.T(Id).t =
     fun ~public_input_size ~public_output_size ~self i tags statements ->
      match tags with
      | [] ->
          []
      | tag :: tags ->
          let (Typ typ) =
            get_typ ~public_input_size ~public_output_size tag self
          in
          let input, output = Array.get statements i in
          let fields = Array.concat [ input; output ] in
          let aux = typ.constraint_system_auxiliary () in
          let statement = typ.var_of_fields (fields, aux) in
          statement
          :: prev_statements ~public_input_size ~public_output_size ~self
               (i + 1) tags statements

    let prev_statements ~public_input_size ~public_output_size ~self tags
        statements =
      prev_statements ~public_input_size ~public_output_size ~self 0 tags
        statements

    let create ~public_input_size ~public_output_size (rule : pickles_rule_js) :
        ( _
        , _
        , _
        , _
        , Public_input.t
        , Public_input.Constant.t
        , Public_input.t
        , Public_input.Constant.t
        , unit
        , unit )
        t =
      let (Prevs prevs) = Prevs.of_rule rule in

      (* this is called after `picklesRuleFromFunction()` and finishes the circuit *)
      let finish_circuit prevs (Tag.Tag self)
          (js_result : pickles_rule_js_return) :
          _ Pickles.Inductive_rule.main_return =
        (* convert js rule output to pickles rule output *)
        let public_output = js_result##.publicOutput in
        let previous_proofs_should_verify =
          should_verifys prevs js_result##.shouldVerify
        in
        let previous_public_inputs =
          prev_statements ~public_input_size ~public_output_size ~self prevs
            js_result##.previousStatements
        in
        let previous_proof_statements =
          let rec go :
              type prev_vars prev_values widths heights.
                 int
              -> prev_vars H1.T(Id).t
              -> prev_vars H1.T(E01(Pickles.Inductive_rule.B)).t
              -> (prev_vars, prev_values, widths, heights) H4.T(Pickles.Tag).t
              -> ( prev_vars
                 , widths )
                 H2.T(Pickles.Inductive_rule.Previous_proof_statement).t =
           fun i public_inputs should_verifys tags ->
            match (public_inputs, should_verifys, tags) with
            | [], [], [] ->
                []
            | ( public_input :: public_inputs
              , proof_must_verify :: should_verifys
              , _tag :: tags ) ->
                let proof =
                  Impl.exists (Impl.Typ.prover_value ()) ~compute:(fun () ->
                      Array.get js_result##.previousProofs i
                      |> unsafe_coerce_proof )
                in
                { public_input; proof; proof_must_verify }
                :: go (i + 1) public_inputs should_verifys tags
          in
          go 0 previous_public_inputs previous_proofs_should_verify prevs
        in
        { previous_proof_statements; public_output; auxiliary_output = () }
      in

      let rule ~(self : (Statement.t, Statement.Constant.t, _) Tag.t) :
          _ Pickles.Inductive_rule.Promise.t =
        let prevs = prevs ~self in

        let main ({ public_input } : _ Pickles.Inductive_rule.main_input) =
          (* add dummy constraints *)
          dummy_constraints () ;
          (* circuit from js *)
          rule##.main public_input
          |> Promise_js_helpers.of_js
          |> Promise.map ~f:(finish_circuit prevs self)
        in
        { identifier = Js.to_string rule##.identifier
        ; feature_flags =
            Pickles_types.Plonk_types.Features.map rule##.featureFlags
              ~f:(function
              | Some true ->
                  true
              | _ ->
                  false )
        ; prevs
        ; main
        }
      in
      Rule rule
  end

  type ( 'var
       , 'value
       , 'width
       , 'height
       , 'arg_var
       , 'arg_value
       , 'ret_var
       , 'ret_value
       , 'auxiliary_var
       , 'auxiliary_value )
       t =
    | Choices :
        (   self:('var, 'value, 'width) Tag.t
         -> ( _
            , 'prev_vars
            , 'prev_values
            , 'widths
            , 'heights
            , 'arg_var
            , 'arg_value
            , 'ret_var
            , 'ret_value
            , 'auxiliary_var
            , 'auxiliary_value )
            H4_6_with_length.T(Pickles.Inductive_rule.Promise).t )
        -> ( 'var
           , 'value
           , 'width
           , 'height
           , 'arg_var
           , 'arg_value
           , 'ret_var
           , 'ret_value
           , 'auxiliary_var
           , 'auxiliary_value )
           t

  (* Convert each rule given in js_rules as JS object into their corresponding
     OCaml type counterparty *)
  let of_js ~public_input_size ~public_output_size js_rules =
    let rec get_rules (Choices rules) index :
        ( _
        , _
        , _
        , _
        , Public_input.t
        , Public_input.Constant.t
        , Public_input.t
        , Public_input.Constant.t
        , unit
        , unit )
        t =
      if index < 0 then Choices rules
      else
        let (Rule rule) =
          Inductive_rule.create ~public_input_size ~public_output_size
            (Array.get js_rules index)
        in
        let rules ~self : _ H4_6_with_length.T(Pickles.Inductive_rule.Promise).t
            =
          rule ~self :: rules ~self
        in
        get_rules (Choices rules) (index - 1)
    in
    get_rules (Choices (fun ~self:_ -> [])) (Array.length js_rules - 1)
end

module Cache = struct
  module Sync : Key_cache.Sync = struct
    open Key_cache
    include T (Or_error)

    module Disk_storable = struct
      include Disk_storable (Or_error)

      let of_binable = Trivial.Disk_storable.of_binable

      let simple to_string read write = { to_string; read; write }
    end

    let read spec { Disk_storable.to_string; read; write = _ } key =
      Or_error.find_map_ok spec ~f:(fun s ->
          let res, cache_hit =
            match s with
            | Spec.On_disk { should_write; _ } ->
                let path = to_string key in
                ( read ~path key
                , if should_write then `Locally_generated else `Cache_hit )
            | S3 _ ->
                (Or_error.errorf "Downloading from S3 is disabled", `Cache_hit)
          in
          Or_error.map res ~f:(fun res -> (res, cache_hit)) )

    let write spec { Disk_storable.to_string; read = _; write } key value =
      let errs =
        List.filter_map spec ~f:(fun s ->
            let res =
              match s with
              | Spec.On_disk { should_write; _ } ->
                  if should_write then write key value (to_string key)
                  else Or_error.return ()
              | S3 _ ->
                  Or_error.return ()
            in
            match res with Error e -> Some e | Ok () -> None )
      in
      match errs with [] -> Ok () | errs -> Error (Error.of_list errs)
  end

  let () = Key_cache.set_sync_implementation (module Sync)

  open Pickles.Cache

  type any_key =
    | Step_pk of Step.Key.Proving.t
    | Step_vk of Step.Key.Verification.t
    | Wrap_pk of Wrap.Key.Proving.t
    | Wrap_vk of Wrap.Key.Verification.t

  type any_value =
    | Step_pk of Backend.Tick.Keypair.t
    | Step_vk of Kimchi_bindings.Protocol.VerifierIndex.Fp.t
    | Wrap_pk of Backend.Tock.Keypair.t
    | Wrap_vk of Pickles.Verification_key.t

  let step_pk = function Step_pk v -> Ok v | _ -> Or_error.errorf "step_pk"

  let step_vk = function Step_vk v -> Ok v | _ -> Or_error.errorf "step_vk"

  let wrap_pk = function Wrap_pk v -> Ok v | _ -> Or_error.errorf "wrap_pk"

  let wrap_vk = function Wrap_vk v -> Ok v | _ -> Or_error.errorf "wrap_vk"

  type js_storable =
    { read : any_key -> Js.js_string Js.t -> (any_value, unit) result
    ; write : any_key -> any_value -> Js.js_string Js.t -> (unit, unit) result
    ; can_write : bool
    }

  let or_error f = function Ok v -> f v | _ -> Or_error.errorf "failed"

  let map_error = function Ok v -> Ok v | _ -> Or_error.errorf "failed"

  let step_storable { read; write; _ } : Step.storable =
    let read key ~path =
      read (Step_pk key) (Js.string path) |> or_error step_pk
    in
    let write key value path =
      write (Step_pk key) (Step_pk value) (Js.string path) |> map_error
    in
    Sync.Disk_storable.simple Step.Key.Proving.to_string read write

  let step_vk_storable { read; write; _ } : Step.vk_storable =
    let read key ~path =
      read (Step_vk key) (Js.string path) |> or_error step_vk
    in
    let write key value path =
      write (Step_vk key) (Step_vk value) (Js.string path) |> map_error
    in
    Sync.Disk_storable.simple Step.Key.Verification.to_string read write

  let wrap_storable { read; write; _ } : Wrap.storable =
    let read key ~path =
      read (Wrap_pk key) (Js.string path) |> or_error wrap_pk
    in
    let write key value path =
      write (Wrap_pk key) (Wrap_pk value) (Js.string path) |> map_error
    in
    Sync.Disk_storable.simple Wrap.Key.Proving.to_string read write

  let wrap_vk_storable { read; write; _ } : Wrap.vk_storable =
    let read key ~path =
      read (Wrap_vk key) (Js.string path) |> or_error wrap_vk
    in
    let write key value path =
      write (Wrap_vk key) (Wrap_vk value) (Js.string path) |> map_error
    in
    Sync.Disk_storable.simple Wrap.Key.Verification.to_string read write
    (* TODO get this code to understand equivalence of versions of Pickles.Verification_key.t *)
    |> Obj.magic

  let storables s : Pickles.Storables.t =
    { step_storable = step_storable s
    ; step_vk_storable = step_vk_storable s
    ; wrap_storable = wrap_storable s
    ; wrap_vk_storable = wrap_vk_storable s
    }

  let cache_dir { can_write; _ } : Key_cache.Spec.t list =
    let d : Key_cache.Spec.t =
      On_disk { directory = ""; should_write = can_write }
    in
    [ d ]
end

module Public_inputs_with_proofs =
  Pickles_types.Hlist.H2.T (Pickles.Statement_with_proof)

let nat_modules_list : (module Pickles_types.Nat.Intf) list =
  let open Pickles_types.Nat in
  [ (module N0)
  ; (module N1)
  ; (module N2)
  ; (module N3)
  ; (module N4)
  ; (module N5)
  ; (module N6)
  ; (module N7)
  ; (module N8)
  ; (module N9)
  ; (module N10)
  ; (module N11)
  ; (module N12)
  ; (module N13)
  ; (module N14)
  ; (module N15)
  ; (module N16)
  ; (module N17)
  ; (module N18)
  ; (module N19)
  ; (module N20)
  ; (module N21)
  ; (module N22)
  ; (module N23)
  ; (module N24)
  ; (module N25)
  ; (module N26)
  ; (module N27)
  ; (module N28)
  ; (module N29)
  ; (module N30)
  ]

let nat_add_modules_list : (module Pickles_types.Nat.Add.Intf) list =
  let open Pickles_types.Nat in
  [ (module N0)
  ; (module N1)
  ; (module N2)
  ; (module N3)
  ; (module N4)
  ; (module N5)
  ; (module N6)
  ; (module N7)
  ; (module N8)
  ; (module N9)
  ; (module N10)
  ; (module N11)
  ; (module N12)
  ; (module N13)
  ; (module N14)
  ; (module N15)
  ; (module N16)
  ; (module N17)
  ; (module N18)
  ; (module N19)
  ; (module N20)
  ; (module N21)
  ; (module N22)
  ; (module N23)
  ; (module N24)
  ; (module N25)
  ; (module N26)
  ; (module N27)
  ; (module N28)
  ; (module N29)
  ; (module N30)
  ]

let nat_module (i : int) : (module Pickles_types.Nat.Intf) =
  List.nth_exn nat_modules_list i

let nat_add_module (i : int) : (module Pickles_types.Nat.Add.Intf) =
  List.nth_exn nat_add_modules_list i

let name = "smart-contract"

let pickles_compile (choices : pickles_rule_js array)
    (config :
      < publicInputSize : int Js.prop
      ; publicOutputSize : int Js.prop
      ; storable : Cache.js_storable Js.optdef_prop
      ; overrideWrapDomain : int Js.optdef_prop
      ; numChunks : int Js.optdef_prop
      ; lazyMode : bool Js.optdef_prop >
      Js.t ) =
  (* translate number of branches and recursively verified proofs from JS *)
  let branches = Array.length choices in
  let max_proofs =
    let choices = choices |> Array.to_list in
    List.map choices ~f:(fun c -> c##.proofsToVerify |> Array.length)
    |> List.max_elt ~compare |> Option.value ~default:0
  in
  let (module Branches) = nat_module branches in
  let (module Max_proofs_verified) = nat_add_module max_proofs in

  (* translate method circuits from JS *)
  let public_input_size = config##.publicInputSize in
  let public_output_size = config##.publicOutputSize in
  let override_wrap_domain =
    Js.Optdef.to_option config##.overrideWrapDomain
    |> Option.map ~f:Pickles_base.Proofs_verified.of_int_exn
  in
  let num_chunks = Js.Optdef.get config##.numChunks (fun () -> 1) in
  let lazy_mode = Js.Optdef.get config##.lazyMode (fun () -> false) in
  let (Choices choices) =
    Choices.of_js ~public_input_size ~public_output_size choices
  in
  let choices ~self = choices ~self:(Choices.Tag.Tag self) in

  (* parse caching configuration *)
  let storables =
    Js.Optdef.to_option config##.storable |> Option.map ~f:Cache.storables
  in
  let cache =
    Js.Optdef.to_option config##.storable |> Option.map ~f:Cache.cache_dir
  in

  (* call into Pickles *)
  let tag, _cache, p, provers =
    Pickles.compile_promise ?cache ?storables ?override_wrap_domain
      ~public_input:
        (Input_and_output
           ( public_input_typ public_input_size
           , public_input_typ public_output_size ) )
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Max_proofs_verified)
      ~name ~num_chunks ~lazy_mode ~choices ()
  in

  (* translate returned prover and verify functions to JS *)
  let module Proof = (val p) in
  let to_js_prover prover : Proof.t js_prover =
    let prove (public_input : Public_input.Constant.t) =
      prover public_input
      |> Promise.map ~f:(fun (output, _, proof) -> (output, proof))
      |> Promise_js_helpers.to_js
    in
    prove
  in
  let rec to_js_provers :
      type a b c.
         ( a
         , b
         , c
         , Public_input.Constant.t
         , (Public_input.Constant.t * unit * Proof.t) Promise.t )
         Pickles.Provers.t
      -> Proof.t js_prover list = function
    | [] ->
        []
    | p :: ps ->
        to_js_prover p :: to_js_provers ps
  in
  let provers : Proof.t js_prover array =
    provers |> to_js_provers |> Array.of_list
  in
  let verify (statement : Statement.Constant.t) (proof : _ Pickles.Proof.t) =
    Proof.verify_promise [ (statement, proof) ]
    |> Promise.map ~f:(fun x -> Js.bool (Or_error.is_ok x))
    |> Promise_js_helpers.to_js
  in
  let get_vk () =
    let vk = Pickles.Side_loaded.Verification_key.of_compiled_promise tag in
    Promise.map vk ~f:(fun vk ->
        let data = Pickles.Side_loaded.Verification_key.to_base64 vk in
        let hash = Mina_base.Zkapp_account.digest_vk vk in
        (data |> Js.string, hash) )
    |> Promise_js_helpers.to_js
  in
  object%js
    val provers = Obj.magic provers

    val verify = Obj.magic verify

    val tag = Obj.magic tag

    val getVerificationKey = get_vk
  end

module Proof0 = Pickles.Proof.Make (Pickles_types.Nat.N0)
module Proof1 = Pickles.Proof.Make (Pickles_types.Nat.N1)
module Proof2 = Pickles.Proof.Make (Pickles_types.Nat.N2)

type some_proof = Proof0 of Proof0.t | Proof1 of Proof1.t | Proof2 of Proof2.t

let proof_to_base64 = function
  | Proof0 proof ->
      Proof0.to_base64 proof |> Js.string
  | Proof1 proof ->
      Proof1.to_base64 proof |> Js.string
  | Proof2 proof ->
      Proof2.to_base64 proof |> Js.string

let proof_of_base64 str i : some_proof =
  let str = Js.to_string str in
  match i with
  | 0 ->
      Proof0 (Proof0.of_base64 str |> Result.ok_or_failwith)
  | 1 ->
      Proof1 (Proof1.of_base64 str |> Result.ok_or_failwith)
  | 2 ->
      Proof2 (Proof2.of_base64 str |> Result.ok_or_failwith)
  | _ ->
      failwith "invalid proof index"

let verify (statement : Statement.Constant.t) (proof : proof)
    (vk : Js.js_string Js.t) =
  let i, o = statement in
  let typ = statement_typ (Array.length i) (Array.length o) in
  let proof = Pickles.Side_loaded.Proof.of_proof proof in
  let vk =
    match Pickles.Side_loaded.Verification_key.of_base64 (Js.to_string vk) with
    | Ok vk_ ->
        vk_
    | Error err ->
        failwithf "Could not decode base64 verification key: %s"
          (Error.to_string_hum err) ()
  in
  Pickles.Side_loaded.verify_promise ~typ [ (vk, statement, proof) ]
  |> Promise.map ~f:(fun x -> Js.bool (Or_error.is_ok x))
  |> Promise_js_helpers.to_js

let load_srs_fp () = Backend.Tick.Keypair.load_urs ()

let load_srs_fq () = Backend.Tock.Keypair.load_urs ()

let dummy_proof (max_proofs_verified : int) (domain_log2 : int) : some_proof =
  match max_proofs_verified with
  | 0 ->
      let n = Pickles_types.Nat.N0.n in
      Proof0 (Pickles.Proof.dummy n n ~domain_log2)
  | 1 ->
      let n = Pickles_types.Nat.N1.n in
      Proof1 (Pickles.Proof.dummy n n ~domain_log2)
  | 2 ->
      let n = Pickles_types.Nat.N2.n in
      Proof2 (Pickles.Proof.dummy n n ~domain_log2)
  | _ ->
      failwith "invalid"

let dummy_verification_key () =
  let vk = Pickles.Side_loaded.Verification_key.dummy in
  let data = Pickles.Side_loaded.Verification_key.to_base64 vk in
  let hash = Mina_base.Zkapp_account.digest_vk vk in
  (data |> Js.string, hash)

let encode_verification_key (vk : Pickles.Verification_key.t) =
  Pickles.Verification_key.to_yojson vk |> Yojson.Safe.to_string |> Js.string

let decode_verification_key (bytes : Js.js_string Js.t) =
  let vk_or_error =
    Pickles.Verification_key.of_yojson @@ Yojson.Safe.from_string
    @@ Js.to_string bytes
  in
  let open Ppx_deriving_yojson_runtime.Result in
  match vk_or_error with
  | Ok vk ->
      vk
  | Error err ->
      failwithf "Could not decode verification key: %s" err ()

module Util = struct
  let to_ml_string s = Js.to_string s

  let from_ml_string s = Js.string s
end

let side_loaded_create (name : Js.js_string Js.t) (max_proofs_verified : int)
    (public_input_length : int) (public_output_length : int)
    (feature_flags_js : bool option Pickles_types.Plonk_types.Features.t) =
  let name = Js.to_string name in
  let feature_flags = map_feature_flags_option feature_flags_js in
  let typ = statement_typ public_input_length public_output_length in
  match max_proofs_verified with
  | 0 ->
      Obj.magic
      @@ Pickles.Side_loaded.create ~name
           ~max_proofs_verified:(module Pickles_types.Nat.N0)
           ~feature_flags ~typ
  | 1 ->
      Obj.magic
      @@ Pickles.Side_loaded.create ~name
           ~max_proofs_verified:(module Pickles_types.Nat.N1)
           ~feature_flags ~typ
  | 2 ->
      Obj.magic
      @@ Pickles.Side_loaded.create ~name
           ~max_proofs_verified:(module Pickles_types.Nat.N2)
           ~feature_flags ~typ
  | _ ->
      failwith "side_loaded_create is unhappy; you should pass 0, 1, or 2"

let vk_to_circuit vk =
  let vk () =
    match
      Pickles.Side_loaded.Verification_key.of_base64 (Js.to_string (vk ()))
    with
    | Ok vk_ ->
        vk_
    | Error err ->
        failwithf "Could not decode base64 verification key: %s"
          (Error.to_string_hum err) ()
  in
  Impl.exists Pickles.Side_loaded.Verification_key.typ ~compute:(fun () ->
      vk () )

let vk_digest vk =
  Pickles.Side_loaded.Verification_key.Checked.to_input vk
  |> Random_oracle.Checked.pack_input

let in_circuit tag checked_vk = Pickles.Side_loaded.in_circuit tag checked_vk

let in_prover tag (vk : Js.js_string Js.t) =
  let vk =
    match Pickles.Side_loaded.Verification_key.of_base64 (Js.to_string vk) with
    | Ok vk_ ->
        vk_
    | Error err ->
        failwithf "Could not decode base64 verification key: %s"
          (Error.to_string_hum err) ()
  in
  Pickles.Side_loaded.in_prover tag vk

let pickles =
  object%js
    val compile = pickles_compile

    val verify = verify

    val loadSrsFp = load_srs_fp

    val loadSrsFq = load_srs_fq

    val dummyProof = dummy_proof

    val dummyVerificationKey = dummy_verification_key

    val proofToBase64 = proof_to_base64

    val proofOfBase64 = proof_of_base64

    val proofToBase64Transaction =
      fun (proof : proof) ->
        proof |> Pickles.Side_loaded.Proof.of_proof
        |> Pickles.Side_loaded.Proof.to_base64 |> Js.string

    val encodeVerificationKey = encode_verification_key

    val decodeVerificationKey = decode_verification_key

    val util =
      object%js
        val toMlString = Util.to_ml_string

        val fromMlString = Util.from_ml_string
      end

    val sideLoaded =
      object%js
        val create = side_loaded_create

        val inCircuit =
          (* We get weak variables here, but they're synthetic. Don't try this
             at home.
          *)
          Obj.magic in_circuit

        val inProver =
          (* We get weak variables here, but they're synthetic. Don't try this
             at home.
          *)
          Obj.magic in_prover

        val vkToCircuit = vk_to_circuit

        val vkDigest = vk_digest
      end
  end
