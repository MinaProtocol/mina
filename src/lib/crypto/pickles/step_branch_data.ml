open Core_kernel
open Pickles_types
open Hlist
open Import

module Make (Inductive_rule : Inductive_rule.Intf) = struct
  (* The data obtained from "compiling" an inductive rule into a circuit. *)
  type ( 'a_var
       , 'a_value
       , 'ret_var
       , 'ret_value
       , 'auxiliary_var
       , 'auxiliary_value
       , 'max_proofs_verified
       , 'branches
       , 'prev_vars
       , 'prev_values
       , 'local_widths
       , 'local_heights )
       t =
    | T :
        { proofs_verified :
            'proofs_verified Nat.t
            * ('prev_vars, 'proofs_verified) Hlist.Length.t
        ; index : int
        ; lte : ('proofs_verified, 'max_proofs_verified) Nat.Lte.t
        ; domains : Domains.t Promise.t
        ; rule :
            ( 'prev_vars
            , 'prev_values
            , 'local_widths
            , 'local_heights
            , 'a_var
            , 'a_value
            , 'ret_var
            , 'ret_value
            , 'auxiliary_var
            , 'auxiliary_value )
            Inductive_rule.Promise.t
        ; main :
               step_domains:(Domains.t, 'branches) Vector.t Promise.t
            -> (   unit
                -> ( (Unfinalized.t, 'max_proofs_verified) Vector.t
                   , Impls.Step.Field.t
                   , (Impls.Step.Field.t, 'max_proofs_verified) Vector.t )
                   Types.Step.Statement.t
                   Promise.t )
               Promise.t
        ; requests :
            (module Requests.Step(Inductive_rule).S
               with type statement = 'a_value
                and type max_proofs_verified = 'max_proofs_verified
                and type proofs_verified = 'proofs_verified
                and type prev_values = 'prev_values
                and type local_signature = 'local_widths
                and type local_branches = 'local_heights
                and type return_value = 'ret_value
                and type auxiliary_value = 'auxiliary_value )
        ; prev_requests :
            'local_widths Hlist.H1.T(Requests.Prev_request_packed).t
        ; feature_flags : bool Plonk_types.Features.t
        }
        -> ( 'a_var
           , 'a_value
           , 'ret_var
           , 'ret_value
           , 'auxiliary_var
           , 'auxiliary_value
           , 'max_proofs_verified
           , 'branches
           , 'prev_vars
           , 'prev_values
           , 'local_widths
           , 'local_heights )
           t

  (* Compile an inductive rule. *)
  let create
      (type branches max_proofs_verified var value a_var a_value ret_var
      ret_value ) ~index
      ~(self : (var, value, max_proofs_verified, branches) Tag.t) ~wrap_domains
      ~(feature_flags : Opt.Flag.t Plonk_types.Features.Full.t) ~num_chunks
      ~(actual_feature_flags : bool Plonk_types.Features.t)
      ~(max_proofs_verified : max_proofs_verified Nat.t)
      ~(branches : branches Nat.t)
      ~(public_input :
         ( var
         , value
         , a_var
         , a_value
         , ret_var
         , ret_value )
         Inductive_rule.public_input ) ~auxiliary_typ _var_to_field_elements
      _value_to_field_elements ~(chain_to : unit Promise.t)
      (rule : _ Inductive_rule.Promise.t) =
    Timer.clock __LOC__ ;
    let module HT = H4.T (Tag) in
    let (T (self_width, proofs_verified)) = HT.length rule.prevs in
    let rec extract_lengths :
        type a b n m k.
        (a, b, n, m) HT.t -> (a, k) Length.t -> n H1.T(Nat).t * (n, k) Length.t
        =
     fun ts len ->
      match (ts, len) with
      | [], Z ->
          ([], Z)
      | t :: ts, S len -> (
          let ns, len_ns = extract_lengths ts len in
          match Type_equal.Id.same_witness self.id t.id with
          | Some T ->
              (max_proofs_verified :: ns, S len_ns)
          | None ->
              let (module M) =
                match t.kind with
                | Compiled ->
                    let d = Types_map.lookup_compiled t.id in
                    d.max_proofs_verified
                | Side_loaded ->
                    let d = Types_map.lookup_side_loaded t.id in
                    d.permanent.max_proofs_verified
              in
              let T = M.eq in
              (M.n :: ns, S len_ns) )
    in
    Timer.clock __LOC__ ;
    let widths, local_signature_length =
      extract_lengths rule.prevs proofs_verified
    in
    let lte = Nat.lte_exn self_width max_proofs_verified in
    let module Step_requests = Requests.Step (Inductive_rule) in
    let requests = Step_requests.create () in
    (* One request module per predecessor, minted distinctly per prev (so the
       step circuit and handler can dispatch each predecessor's requests
       directly) and carrying that predecessor's width, feature flags and chunk
       count — everything fixing its witness layout. Built here, alongside
       [requests], where the per-prev data is in scope, then carried in an hlist
       and threaded through to both the step circuit and its handler. *)
    let feature_flags_and_num_chunks (d : _ Tag.t) =
      if Type_equal.Id.same self.id d.id then (feature_flags, num_chunks)
      else (Types_map.feature_flags d, Types_map.num_chunks d)
    in
    let prev_requests =
      let make_one :
          type w.
             w Nat.t
          -> Opt.Flag.t Plonk_types.Features.Full.t
          -> int
          -> w Requests.Prev_request_packed.t =
       fun width feature_flags num_chunks :
           (module Requests.Prev_request with type width = w) ->
        ( module Requests.Make_prev_request
                   (struct
                     type n = w

                     let n = width

                     let feature_flags = feature_flags

                     let num_chunks = num_chunks
                   end)
                   () )
      in
      let rec go :
          type pvars pvals ws hs.
             (pvars, pvals, ws, hs) H4.T(Tag).t
          -> ws H1.T(Nat).t
          -> ws H1.T(Requests.Prev_request_packed).t =
       fun ds widths ->
        match (ds, widths) with
        | [], [] ->
            []
        | d :: ds, width :: widths ->
            let feature_flags, num_chunks = feature_flags_and_num_chunks d in
            make_one width feature_flags num_chunks :: go ds widths
      in
      go rule.prevs widths
    in
    let (typ : (var, value) Impls.Step.Typ.t) =
      match public_input with
      | Input typ ->
          typ
      | Output typ ->
          typ
      | Input_and_output (input_typ, output_typ) ->
          Impls.Step.Typ.(input_typ * output_typ)
    in
    (* Here, we prefetch the known wrap keys for all compiled rules.
       These keys may resolve asynchronously due to key generation for other
       pickles rules, but we want to preserve the single-threaded behavior of
       pickles to maximize our chances of successful debugging.
       Hence, we preload here, and pass the values in as needed when we create
       [datas] below.
    *)
    let module Optional_wrap_key = Types_map.For_step.Optional_wrap_key in
    let known_wrap_keys =
      let rec go :
          type a1 a2 n m.
          (a1, a2, n, m) H4.T(Tag).t -> m H1.T(Optional_wrap_key).t Promise.t =
        function
        | [] ->
            Promise.return ([] : _ H1.T(Optional_wrap_key).t)
        | tag :: tags ->
            let%bind.Promise opt_wrap_key =
              match Type_equal.Id.same_witness self.id tag.id with
              | Some T ->
                  Promise.return None
              | None -> (
                  match tag.kind with
                  | Compiled ->
                      let compiled = Types_map.lookup_compiled tag.id in
                      let%map.Promise wrap_key = Lazy.force compiled.wrap_key
                      and step_domains =
                        let%map.Promise () =
                          (* Wait for promises to resolve. *)
                          Vector.fold ~init:(Promise.return ())
                            compiled.step_domains ~f:(fun acc step_domain ->
                              let%bind.Promise _ = step_domain in
                              acc )
                        in
                        Vector.map
                          ~f:(fun x -> Option.value_exn @@ Promise.peek x)
                          compiled.step_domains
                      in
                      Some { Optional_wrap_key.wrap_key; step_domains }
                  | Side_loaded ->
                      Promise.return None )
            in
            let%map.Promise rest = go tags in
            (opt_wrap_key :: rest : _ H1.T(Optional_wrap_key).t)
      in
      go rule.prevs
    in
    Timer.clock __LOC__ ;
    let module Step_main = Step_main.Make (Inductive_rule) in
    let step ~step_domains ~known_wrap_keys =
      Step_main.step_main requests
        (Nat.Add.create max_proofs_verified)
        rule
        ~basic:
          { public_input = typ
          ; wrap_domains
          ; step_domains
          ; feature_flags
          ; num_chunks
          ; zk_rows =
              ( match num_chunks with
              | 1 (* cannot match with Plonk_checks.num_chunks_by_default *) ->
                  Plonk_checks.zk_rows_by_default
              | num_chunks ->
                  let permuts = 7 in
                  ((2 * (permuts + 1) * num_chunks) - 2 + permuts) / permuts )
          }
        ~public_input ~auxiliary_typ ~self_branches:branches ~proofs_verified
        ~prev_requests ~local_signature_length ~lte ~known_wrap_keys ~self
      |> unstage
    in
    Timer.clock __LOC__ ;
    let own_domains =
      let%bind.Promise known_wrap_keys = known_wrap_keys in
      let main =
        step
          ~step_domains:
            (Vector.init branches ~f:(fun _ -> Fix_domains.rough_domains))
          ~known_wrap_keys
      in
      let etyp =
        Impls.Step.input ~proofs_verified:max_proofs_verified
        (* TODO *)
      in
      let%bind.Promise () = chain_to in
      Fix_domains.domains ~feature_flags:actual_feature_flags
        (T (Impls.Step.Typ.unit, Fn.id, Fn.id))
        etyp main
    in
    let step ~step_domains =
      let%bind.Promise known_wrap_keys = known_wrap_keys in
      let%map.Promise step_domains = step_domains in
      step ~step_domains ~known_wrap_keys
    in
    Timer.clock __LOC__ ;
    T
      { proofs_verified = (self_width, proofs_verified)
      ; index
      ; lte
      ; rule
      ; domains = own_domains
      ; main = step
      ; requests
      ; prev_requests
      ; feature_flags = actual_feature_flags
      }
end
