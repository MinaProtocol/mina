open Core
open Pickles

type _ Snarky_backendless.Request.t +=
  | Get_score :
      Pickles.Impls.Step.Internal_Basic.Field.t Snarky_backendless.Request.t

let target_score = 700

module Eth_address : sig
  type t

  val of_string : string -> t

  val to_string : t -> string

  val to_field : t -> Impls.Step.Field.Constant.t

  val of_field : Impls.Step.Field.Constant.t -> t
end = struct
  type t = string

  let of_string s =
    let s = String.chop_prefix_exn ~prefix:"0x" s in
    assert (String.length s = 40) ;
    Hex.decode ~init:String.init s

  let to_string t = "0x" ^ Hex.encode t

  let to_bits t =
    List.init
      (String.length t * 8)
      ~f:(fun i ->
        let j = i mod 8 in
        (Char.to_int t.[i / 8] lsr j) land 1 = 1 )

  let of_bits bs : t =
    List.map (List.chunks_of bs ~length:8) ~f:(fun byte ->
        List.foldi byte ~init:0 ~f:(fun i acc bit ->
            if bit then acc lor (1 lsl i) else acc )
        |> Char.of_int_exn )
    |> String.of_char_list

  let to_field = Fn.compose Snark_params.Tick.Field.project to_bits

  let of_field = Fn.compose of_bits Snark_params.Tick.Field.unpack
end

let dummy_constraints () =
  let module Impl = Pickles.Impls.Step in
  let module Inner_curve = Pickles.Step_main_inputs.Inner_curve in
  let open Impl in
  make_checked (fun () ->
      let b = exists Boolean.typ_unchecked ~compute:(fun _ -> true) in
      let g =
        exists Inner_curve.typ ~compute:(fun _ -> Inner_curve.Params.one)
      in
      let _ =
        Pickles.Step_main_inputs.Ops.scale_fast g (`Plus_two_to_len [|b; b|])
      in
      let _ =
        Pickles.Pairing_main.Scalar_challenge.endo g (Scalar_challenge [b])
      in
      () )

let main (_ : Mina_base.Snapp_statement.Checked.t) =
  let open Pickles.Impls.Step.Internal_Basic in
  let open Checked.Let_syntax in
  let%bind () = dummy_constraints () in
  let%bind score = exists Field.typ ~request:As_prover.(return Get_score) in
  (* 10 bits because maximum score is 850. *)
  let%bind () =
    as_prover
      As_prover.(
        let%map score = read Field.typ score in
        if Field.(compare score (of_int target_score)) < 0 then
          Format.eprintf
            "The score %s is less than the target score %i.@ Unable to \
             generate a proof.@."
            (Field.to_string score) target_score)
  in
  Field.Checked.Assert.gte ~bit_length:10 score
    Field.(Var.constant (of_int 700))

include Snapp_runner_functor.Make_with_commands (struct
  module Public_input = struct
    module Value = struct
      include Mina_base.Snapp_statement

      let if_not_given = `Raise

      let args : t option Command.Spec.param =
        let open Command in
        let open Command.Let_syntax in
        let%map snapp_pk =
          Command.Param.flag "--snapp-public-key"
            ~doc:"PK Public key of the snapp account"
            (Flag.optional Cli_lib.Arg_type.public_key_compressed)
        and receiver_pk =
          Command.Param.flag "--receiver-public-key"
            ~doc:"PK Public key of the receiver account"
            (Flag.optional Cli_lib.Arg_type.public_key_compressed)
        and fee =
          Command.Param.flag "--fee"
            ~doc:
              "NUM The fee amount for the snapp account to pay the block \
               producer"
            (Flag.optional
               (Arg_type.map ~f:Unsigned.UInt64.of_string Command.Param.string))
        and amount =
          Command.Param.flag "--amount"
            ~doc:
              "NUM The amount to transfer from the snapp account to the \
               receiver"
            (Flag.optional
               (Arg_type.map ~f:Unsigned.UInt64.of_string Command.Param.string))
        and account_creation_fee =
          Command.Param.flag "--account-creation-fee"
            ~doc:
              "NUM The account creation fee, set by the network, to be paid \
               by the snapp account (default: 100000)"
            (Flag.optional_with_default
               (Unsigned.UInt64.of_string "100000")
               (Arg_type.map ~f:Unsigned.UInt64.of_string Command.Param.string))
        in
        let open Mina_base in
        let open Option.Let_syntax in
        let%map snapp_pk = snapp_pk
        and receiver_pk = receiver_pk
        and fee = fee
        and amount = amount in
        let fee = Currency.Amount.of_uint64 fee in
        let amount = Currency.Amount.of_uint64 amount in
        let account_creation_fee =
          Currency.Amount.of_uint64 account_creation_fee
        in
        let snapp_amount =
          match
            Currency.Amount.(fee + amount >>= ( + ) account_creation_fee)
          with
          | Some snapp_amount ->
              snapp_amount
          | None ->
              eprintf
                "Error computing snapp account delta: fee + amount + \
                 account_creation_fee overflowed." ;
              exit 1
        in
        ( { predicate= Snapp_predicate.accept
          ; body1=
              { pk= snapp_pk
              ; update= Snapp_command.Party.Body.dummy.update
              ; delta=
                  Currency.Amount.Signed.(negate (of_unsigned snapp_amount)) }
          ; body2=
              { pk= receiver_pk
              ; update= Snapp_command.Party.Body.dummy.update
              ; delta= Currency.Amount.Signed.of_unsigned amount } }
          : Snapp_statement.t )
    end

    module Var = Mina_base.Snapp_statement.Checked

    let typ = Mina_base.Snapp_statement.typ
  end

  module Request_data = struct
    type t = int

    let handler x (Snarky_backendless.Request.With {request; respond}) =
      match request with
      | Get_score ->
          respond (Provide Pickles.Impls.Step.Field.(Constant.of_int x))
      | _ ->
          respond Unhandled

    let args =
      Command.Param.flag "--score" ~doc:"NUM Credit score to build a proof for"
        (Command.Flag.required Command.Param.int)
  end

  module Branches = Pickles_types.Nat.N1

  let name = "credit-score-demo"

  let default_cache_location =
    Some Filename.(temp_dir_name ^/ "snapp_credit_score_demo")

  let rule =
    { Inductive_rule.prevs= []
    ; identifier= "demo-base"
    ; main=
        (fun [] i ->
          Pickles.Impls.Step.run_checked (main i) ;
          [] )
    ; main_value= (fun [] _ -> []) }
end)

let snapp_command =
  Fn.flip Sexp.of_string_conv_exn Mina_base.Transaction.t_of_sexp
    {sexp|(Command
 (Snapp_command
  (Proved_empty
   ((token_id 1) (fee_payment ())
    (one
     ((data
       ((body
         ((pk B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8)
          (update
           ((app_state (Keep Keep Keep Keep Keep Keep Keep Keep))
            (delegate Keep) (verification_key Keep) (permissions Keep)))
          (delta ((magnitude 20100000) (sgn Neg)))))
        (predicate
         ((self_predicate
           ((balance Ignore) (nonce Ignore) (receipt_chain_hash Ignore)
            (public_key Ignore) (delegate Ignore)
            (state (Ignore Ignore Ignore Ignore Ignore Ignore Ignore Ignore))))
          (other
           ((predicate
             ((balance Ignore) (nonce Ignore) (receipt_chain_hash Ignore)
              (public_key Ignore) (delegate Ignore)
              (state
               (Ignore Ignore Ignore Ignore Ignore Ignore Ignore Ignore))))
            (account_transition ((prev Any) (next Any))) (account_vk Ignore)))
          (fee_payer Ignore)
          (protocol_state_predicate
           ((snarked_ledger_hash Ignore)
            (snarked_next_available_token Ignore) (timestamp Ignore)
            (blockchain_length Ignore) (min_window_density Ignore)
            (last_vrf_output ()) (total_currency Ignore)
            (curr_global_slot Ignore) (global_slot_since_genesis Ignore)
            (staking_epoch_data
             ((ledger ((hash Ignore) (total_currency Ignore))) (seed Ignore)
              (start_checkpoint Ignore) (lock_checkpoint Ignore)
              (epoch_length Ignore)))
            (next_epoch_data
             ((ledger ((hash Ignore) (total_currency Ignore))) (seed Ignore)
              (start_checkpoint Ignore) (lock_checkpoint Ignore)
              (epoch_length Ignore)))))))))
      (authorization
       (Proof
        ((statement
          ((proof_state
            ((deferred_values
              ((plonk
                ((alpha
                  (Scalar_challenge (bb3b1a937deefb70 f4b6266b324d3d5e)))
                 (beta (716c58af191f6539 453ac33dc7c2cf57))
                 (gamma (9bf803b17ad8b007 14543f29cb40a93a))
                 (zeta
                  (Scalar_challenge (ee54d450c856a6e0 50b63cff5e968933)))))
               (combined_inner_product
                (Shifted_value
                 0x4739e4cdda821448be05df0583f471d88393b3248e90aeea9a45d8c4bd3afd00))
               (b
                (Shifted_value
                 0xaf769c07b057fcab91d2e3261639d7e7e6b07fd34367134d3423ac673313e322))
               (xi (Scalar_challenge (9350496ac729bd00 79949fb1bb03918e)))
               (bulletproof_challenges
                (((prechallenge
                   (Scalar_challenge (c4ec454e51dc345a 1427ac6664705ace))))
                 ((prechallenge
                   (Scalar_challenge (3fd26bfdaf54e4ff b93767cd5beaf2ba))))
                 ((prechallenge
                   (Scalar_challenge (2530d10cc401b2a9 6bd794f26c7c4027))))
                 ((prechallenge
                   (Scalar_challenge (90bf9134e54ffee7 7d720d828e722942))))
                 ((prechallenge
                   (Scalar_challenge (3dc1d44cf20d7703 170133e98ce53fd3))))
                 ((prechallenge
                   (Scalar_challenge (b6759062af78db99 1eea1c2b56ee9bd6))))
                 ((prechallenge
                   (Scalar_challenge (a035111cd5884f0d 32f63a66b17d92b0))))
                 ((prechallenge
                   (Scalar_challenge (2a5c92df60d67369 1a1e3b1a8fd7de23))))
                 ((prechallenge
                   (Scalar_challenge (65187adc7f93e8b0 cab967ea85dc15fc))))
                 ((prechallenge
                   (Scalar_challenge (515c0a1681a6bd5e 46e614efbfd57e4b))))
                 ((prechallenge
                   (Scalar_challenge (c1251c9d82143180 582959fcbac3814a))))
                 ((prechallenge
                   (Scalar_challenge (81731d046490cb9b 9d5013f66f6987b4))))
                 ((prechallenge
                   (Scalar_challenge (79d6e8810b3cb5dc 756a51ced4c981e6))))
                 ((prechallenge
                   (Scalar_challenge (97253e31a6c45f1a 1b4a4f023212dd28))))
                 ((prechallenge
                   (Scalar_challenge (5fb870d5d18d5f83 a799967e98defe4d))))
                 ((prechallenge
                   (Scalar_challenge (94c9b4aa62ae6312 43d2cbf189443e48))))
                 ((prechallenge
                   (Scalar_challenge (a93c31b16d195500 d0b5f4b25b07869c))))
                 ((prechallenge
                   (Scalar_challenge (2b3ed2031f25ef1f dbade298e3047fef))))))
               (which_branch "\000")))
             (sponge_digest_before_evaluations
              (8072c6399fb81f02 8b46997a19901e23 48fa2a7e3655611f
               14d9bd4f7ea353c9))
             (me_only
              ((sg
                (0x94df1449fae11f69576145930fa3cc2be0f8d7f51c1c361d64b8b4b4e1431125
                 0x81a77e7ef86d37398cbb1897f89a7c2cf788bc6f046a67e204e757464cf7e106))
               (old_bulletproof_challenges
                ((((prechallenge
                    (Scalar_challenge (c670b712b8317513 1675cc339a483e08))))
                  ((prechallenge
                    (Scalar_challenge (48c1b0a2b1cab8d1 1b6604e3c071b1ce))))
                  ((prechallenge
                    (Scalar_challenge (3382b3c9ace6bf6f 79974358f9761863))))
                  ((prechallenge
                    (Scalar_challenge (dd3a2b06e9888797 dd7ae6402944a1c7))))
                  ((prechallenge
                    (Scalar_challenge (c6e8e530f49c9fcb 07ddbb65cda09cdd))))
                  ((prechallenge
                    (Scalar_challenge (532c59a287691a13 a921bcb02a656f7b))))
                  ((prechallenge
                    (Scalar_challenge (e29c77b18f10078b f85c5f00df6b0cee))))
                  ((prechallenge
                    (Scalar_challenge (1dbda72d07b09c87 4d1b97e2e95f26a0))))
                  ((prechallenge
                    (Scalar_challenge (9c75747c56805f11 a1fe6369facef1e8))))
                  ((prechallenge
                    (Scalar_challenge (5c2b8adfdbe9604d 5a8c718cf210f79b))))
                  ((prechallenge
                    (Scalar_challenge (22c0b35c51e06b48 a6888b7340a96ded))))
                  ((prechallenge
                    (Scalar_challenge (9007d7b55e76646e c1c68b39db4e8e12))))
                  ((prechallenge
                    (Scalar_challenge (4445e35e373f2bc9 9d40c715fc8ccde5))))
                  ((prechallenge
                    (Scalar_challenge (429882844bbcaa4e 97a927d7d0afb7bc))))
                  ((prechallenge
                    (Scalar_challenge (99ca3d5bfffd6e77 efe66a55155c4294))))
                  ((prechallenge
                    (Scalar_challenge (4b7db27121979954 951fa2e06193c840))))
                  ((prechallenge
                    (Scalar_challenge (2cd1ccbeb20747b3 5bd1de3cf264021d)))))
                 (((prechallenge
                    (Scalar_challenge (c670b712b8317513 1675cc339a483e08))))
                  ((prechallenge
                    (Scalar_challenge (48c1b0a2b1cab8d1 1b6604e3c071b1ce))))
                  ((prechallenge
                    (Scalar_challenge (3382b3c9ace6bf6f 79974358f9761863))))
                  ((prechallenge
                    (Scalar_challenge (dd3a2b06e9888797 dd7ae6402944a1c7))))
                  ((prechallenge
                    (Scalar_challenge (c6e8e530f49c9fcb 07ddbb65cda09cdd))))
                  ((prechallenge
                    (Scalar_challenge (532c59a287691a13 a921bcb02a656f7b))))
                  ((prechallenge
                    (Scalar_challenge (e29c77b18f10078b f85c5f00df6b0cee))))
                  ((prechallenge
                    (Scalar_challenge (1dbda72d07b09c87 4d1b97e2e95f26a0))))
                  ((prechallenge
                    (Scalar_challenge (9c75747c56805f11 a1fe6369facef1e8))))
                  ((prechallenge
                    (Scalar_challenge (5c2b8adfdbe9604d 5a8c718cf210f79b))))
                  ((prechallenge
                    (Scalar_challenge (22c0b35c51e06b48 a6888b7340a96ded))))
                  ((prechallenge
                    (Scalar_challenge (9007d7b55e76646e c1c68b39db4e8e12))))
                  ((prechallenge
                    (Scalar_challenge (4445e35e373f2bc9 9d40c715fc8ccde5))))
                  ((prechallenge
                    (Scalar_challenge (429882844bbcaa4e 97a927d7d0afb7bc))))
                  ((prechallenge
                    (Scalar_challenge (99ca3d5bfffd6e77 efe66a55155c4294))))
                  ((prechallenge
                    (Scalar_challenge (4b7db27121979954 951fa2e06193c840))))
                  ((prechallenge
                    (Scalar_challenge (2cd1ccbeb20747b3 5bd1de3cf264021d)))))))))))
           (pass_through
            ((app_state ()) (sg ()) (old_bulletproof_challenges ())))))
         (prev_evals
          (((l
             (0x055ffb64b256a2c46154479a1dc99aafa8bb42b49ca86dda1243b14a37c1e11c))
            (r
             (0xc8d5a67880ad5a41456b62d50fa46e36083e5c70803b615e496c84ee0420db10))
            (o
             (0x851a1187c7fcf2e7c450db995a643f141bbe67c96bfb7384d3ca333e3d39a41f))
            (z
             (0x1990109117e13ba8b54dbeac5beae50b5d1c5a637230ecbcd75129b257d67b06))
            (t
             (0xc15f3cf60e672fd67b9641f628dedf3e62ee60ea70fc72b31fb71e5b03c78119))
            (f
             (0xfdab70b4686e3e058f81e4439c4ae39fb169668a024225a95ef5a4bd1681641c))
            (sigma1
             (0x62813ab9da17fe1e116fd22a2f26f6a029cd1b8b4c17cdea1bf4365daf019607))
            (sigma2
             (0x42483f4475c1a5ed2918b1343bf8632c47c583e3f5d064119f76cae63e647e13)))
           ((l
             (0x845f8312a2547307c55d374471c7aec113486d2754376c5e072e860df2010032))
            (r
             (0xd92c31032bfb10cd9d0798f10a3b9c2f3168f91b6985c35a9a5e026106574933))
            (o
             (0xb97232319db06cd27540f11be29eee80efe18f5c2969d3f7ae0551b7745e9303))
            (z
             (0xea18701cd14bb3db37ac5129d9cdf321499c526ce81b7c3000b28b1ab289c922))
            (t
             (0xcb282638863a0b411b36c7a193bbb7f858fd9fe9fb9fcf928e60f82df5769011))
            (f
             (0x2b6fa38461595be7222b5c8a761e0a264ec52f3aaf5ef18d3d8f3315fc136006))
            (sigma1
             (0x4e5a517da5e85e8e7436ec517eb5b29fa477bd6acad92a89d982728fa3052a3f))
            (sigma2
             (0x8ae5e22f7d2bf24ca3aef95fe1424e9718a630b7499d9785c91c9b59d06b3126)))))
         (prev_x_hat
          (0x37e0109ef627ff2be3d54e7e68ef9aac7e9a38bfb2d44503426392077fec2f0f
           0x5c7919bff13ce8c2bc2be3beb71f826a496c4e3dd823d402b7d032a0c690761a))
         (proof
          ((messages
            ((l_comm
              ((0x533b37bda82a269f8eea7769f2ee9ef23eda5f685e4c0ee177a4577caa22bb21
                0xc0c25136d2655fe11d60c6d3f1e45783fece69e504f3ad7ec95717f4add7a305)))
             (r_comm
              ((0x5ae5c78a0917203932bd5c0c081b80977f11cceb4d2913884149efec16b0be1a
                0x82cf950dc49d4c5f2af50f5806a58ea4d2e808da4974cc2661799fbcf4030c08)))
             (o_comm
              ((0xcc117091224ff323afe7201e542424ceb5af36aa68d5f5a966706ecc97e7160f
                0x80894b12cc0bbf9859a1d3f430c4bd740f1ed72e3dd866a2b10de5bc531f4a18)))
             (z_comm
              ((0xbbb01edb74b7dcd952df2ec0184187e772783d4b380a67350c0695d3f06cbd22
                0x011d56a7a98db52625fda704b1e67fad40580d16d44dd977b9ad45899dfdfa06)))
             (t_comm
              ((unshifted
                ((Finite
                  (0x0df7f2ce2af2c3144505e496691a66498991f3cf4bbd9386bc17b05f48cf7300
                   0xb76b2d95ff5d9b3ec291641f487d29a107f54925bcd66f9257c22c40dedcbb30))
                 (Finite
                  (0xd4f8c14e6cfed9a08df93167db32696b4306c385671c26ec5db77087f6a9ed0f
                   0x91f631b6028693f0075ee6880c5661103df3e92a4e1ba484ebada4c2cc206904))
                 (Finite
                  (0x1734edf224fe27f6666320d36c57908557233e5e4de468292c9ea970193b2a32
                   0x903ec08fe8a56e40d68a54d6adf2b0e01f7524af78f99fd9ab19251dbc076920))
                 (Finite
                  (0x8a4b2e610397f5ae3b0624f1fbb3ccd27322b47482599fac9417d468f4fdfc09
                   0x37fbdd60cf3499c46464d2816661493587ca6914af09c89564379098df993a35))
                 (Finite
                  (0x93536ad23a2f834ef2ef58921ad6f841dde3f5694d9a0fb593dbbb05ce6b4e0c
                   0xc11b05eda232d020dfd339fd31b6c294e55bd4c112c114ae8a38faf8478fde00))))
               (shifted
                (Finite
                 (0xb6dd6116bfcadce30626e8cc303724ca41ca931ef0a69d2552aaf30969065505
                  0xd994354f278f259f4d0850ffb7e145a39b0437f54041c3eaf10777c87ee37302)))))))
           (openings
            ((proof
              ((lr
                (((0xdbbf4609431fdc587f96a84657aef1232e0c47c56af26093b20df77cb148c929
                   0x478623fd73e8ffe8907867e1cc1891be0731e11ac02b59802e206fce6afd9328)
                  (0x37431ef25f7465dfe32f67e9ac776dc7fbbe8530b80828b7b93246578a5f5c3c
                   0xb08dec05a8a0c13a3dc38d55d800d21a491475133d1c9a176b4df761cd371111))
                 ((0x21dfdcef6c5122d48db26d714dfb6032d33461952dffd67e1fbdf7804ae2a837
                   0x7bb2a3859555258e33c427800dd3d94b290b234e93f9995e733c89dabb628a16)
                  (0x2aef955fd5761e9e8c0fea64425a94a2a7a9cab08a86b6d8e11c116c7d02400d
                   0xa0a4fd50507f004568b8b6cdc3acffab3b77163f2f02c82363487e625e2ab435))
                 ((0xdc7fbfedd10fbc5a313d5c9f6f1db0773eaa1ba4f6947fd5ff131c0a0ece3810
                   0xef3499a61a8eac274a635fe10b10ec14819c36c217bd77258f3749055afb0738)
                  (0xd73f3c15e0d2acb80382d003d12300a070b3b7afe943200045ed774521006b10
                   0x330e387aedaf2314cad627debde1f4433553f8db072d45a1233052c887adf73e))
                 ((0x2f0f79b7e50b4b4a87598770ed569586bde82b1983a7a16559af6ddbfcdd6718
                   0x9a4ab98031aafb342fcfe232148cdf62e51fb7d12dc6722ae82a01aad7b0d612)
                  (0x0e100c0a29fced02d0432cfb92f6edb0f0edce33715d476b37ded55f3131643c
                   0x55653a6be2007545395bbc974f1a399e0226225d2df944015232640392681616))
                 ((0xd3435921fa6a9e08249590c8968aca3c2c8eb499b1271c5890627e0c6397750a
                   0x0769eddfc2d9f07b2a8be0f277133203de96edadf85006e3b26479d97f8d2303)
                  (0xc6b9d9ccf13e550e52437e23c43e71b19269f983b7f7a245a6068a17abdb4733
                   0x209c3f748ddfc3af96b52abfbc795b755a66c6fdf3e539c18698d5f798f79727))
                 ((0x93746509ca908fbf4db2c30b973e352d36dd4ca53bdeb5bc0bb2cf5cfd220409
                   0x0e33cf04d4bd5d1a57b86b11dc4759db1634eb7756cb1aa96560eb9cb1115408)
                  (0xb60908a386e134a4727272d26b8488a85cf2965b8753f7889a892ca7b47aa319
                   0x6d4629c1ac3a6bc6ed341c4ed42eaba9cde2ec90a647b436828ae161ec627103))
                 ((0x6579845ff43164ed0646f424ef66f786b5b905532fdfac5bf60664d710029a2f
                   0x30ac847e0324ed899031121fc6dd1a311eff41ac0b72c5f5eff10b0fc911263d)
                  (0x317139f4c37908e38de9e07cedb849ac2706ba71ef6252287ee5a149ba031d0c
                   0x09897bbe64a441bf9d663e079d8d71a1c064f36a3afcba475e5f4eb838b3dc31))
                 ((0x38e0377c3b8cc2672368ba66d5c76b2f1662dde532307d1ed9ab2e6e61574a27
                   0x4fffac659a2c80d171cf483d91cca16be35d2d1c9ab722b7858dff10176ee429)
                  (0xa5a99e3600ab46be77ba73b332955fc1383935ce23fafbb5003f1e9c15d3a82f
                   0x27747f370c9fa5260a4ca458e0029ee43407524f8a47d4fcf29f3852e43e492a))
                 ((0x3743d5ea0d2d87071c1fccd8afe8241bc056178b0077fb0c9238d7ea4169d129
                   0xd1fafb1bd06b63a1df2b356e7daa4092969c87b8a8b086e7201713128271bd12)
                  (0x5920e95d8ba0f1b17f7be5cc37fd07f1d90b4a71a72cd09bf29e952436357a33
                   0x343665bfd094e50e7ac03723d184dd807fbda6cb5aa098e0bb158e76b11f2e3f))
                 ((0xa4f081ca1339aacb7b1b1dbf9fce31542e2f519c5c37d11b8f762bfe8da0a926
                   0xbf870c724d947ae5e5d08fbab7e060b4f860051936417b2af2dd124bd6739f07)
                  (0xd18378f3aa2f0032c9cb899a92d041c954ecf7b070eec528cb8fb16688985536
                   0xc9dfafacb91fd8b1d50d7c3624d54cf8712f0457cc4d3d19bf0b32a0e22be53f))
                 ((0x32c4cc0962c7bddb011dcdd97dd059271ce69146f120ef74e514682310bc513a
                   0xfb2fd032ef48f7493abd5314ddf5d6e9dccdb7163fbb288538ffbde3d07a8c1d)
                  (0x1c21e62009d7115a5b06ef55af4c8e02b241d0e4eb572a478276a06612d3463e
                   0xdb649c20d95606ca6605ac42cb3e4434ce0aa9e5320e1739b259bb99796a413a))
                 ((0x4b8ee80ede1c859578966ac3f49a00a0b9fd35f9b7d835588efd1307e5bd1d0c
                   0x509225e6e86d8edb5f901e2874f640df124ffc9e6fbef666c1201dca1659c50e)
                  (0x3b964942584aeeed3df7d33f65c48691f2104f1af61a7b8927e5018cdcb67317
                   0x2331ab337378810e9ef44ab00246855582eaae87336bfdea00ce0b710f3dde03))
                 ((0x8803463c438c6c9515e0561e68c076d2e292dfd57a0f6900080ddde1e7026d07
                   0x1106821fd689cc92bfd854ee3902f0b58f810e605af85568efa035b3d4a89905)
                  (0xaa208628adacadff360819335fa57e2b4999a986239e0e47a5087dee1bd6ca21
                   0xbf84c01dbf92048e9351196a6da794df78342d89fa4647ace098086a30958425))
                 ((0x5f0d333e97e15f149dcb8fd493a69e0bc8df8cf0badc88096325c0a046c0e617
                   0x132fb2b82f6a5c5ea00527ca320f3a26e7ff9d06952ca9afbe1acddf8d2e843a)
                  (0x7b3b30ab242182f896a43e75d983314b2c0676dc6b728b01e58cbab7a7667d24
                   0x97e4753382c98a40520d8e960012f13a801631aa88aa739ca605ea5719906804))
                 ((0xc353c02ad43291e7974b9bbe7714b3e789216e6facb967619b657aa45d8b722f
                   0xc68285df7a2e004896f50c89c87f56bf44562f70ec717133ce441ed6ec95142e)
                  (0x3d50d434e54eaf846eeffdcacb9316e89e796aa45dab79b7198556c28f0a083e
                   0xd6efd6e3c1072e4f618f80dd9e07f7a12f481581a86b96a50c2d34b3f3058001))
                 ((0xc1a64cdffa1db03ca3f20258e0c6c2749cab6b3057ec9c6fac6593ca746e1013
                   0x26c347164ea335a1e46b70a26c49d8d873b65d37c82d0ca1e7607f1768f05638)
                  (0x5e53cd48d6867f4e08f0599b6e232254758dad5ec16357801c91e3adc2867c1f
                   0xd0076a2fc8ffe964255b1c92cfc7ea955f761de082d497f2712bde7aa134f100))
                 ((0xe463c84e7903206278c851c641e3a7a16584dd8fb5421bafa266c4c9a085ba0e
                   0x5127fd7046672f1ab988e1c38d243920fcb171ac2c709b6976778f72b1886018)
                  (0x84ce03b6c564863819ba3a9de4e1963755e536cf8bc77384b68e6fa8bb58523a
                   0x683ed9da76fc31335293ed39f80816c573ba07007160b59b70112f7e462bc100))))
               (z_1
                0xcf00c9ca707ec5fd5241057c222c8906f2a71f9f4cdd6ff088a51aa1d08fff2a)
               (z_2
                0x58e688a89abbaef8b39cbc9b0e3dcecc010b08a83b5955e34bef8d251d0f2d35)
               (delta
                (0xc0f11f55803b644c54f8605a69821758527bdaa23fcd7976a55030396ef95607
                 0x3df08f99a26110f314c9d9bc624df4aad5504a2b79d61351238accc262087b3d))
               (sg
                (0x4461df955a50c0b15b5665af514846b4286990ddc816b8a7c39f9c07aedf0939
                 0x8b1ca22380b70418aaeca660ff31c1b298ca8b0f696727c7a40bbc8815e7eb29))))
             (evals
              (((l
                 (0x36049d918dfb0879207b6fc04598944aa812e25e7497efc7b4307eed72583e37))
                (r
                 (0x21f23734064b4c2f5d5bf153fdf9778dfec364cb6dc49a70f3242016890d2b30))
                (o
                 (0xa0d43c08e14a10819fc0c36afdea4599763bca6adebe69251a6f37c2ae8efb0a))
                (z
                 (0x6c868fc3ecff002b668bb8bccf803d64b9d31fa6edb8436953954777a906a22a))
                (t
                 (0x7957549cbc872505a207725a295657da453319bd8337c2a3a6eef14e5b256f12
                  0xab98b107df0e56d6ab23089264ad33b18f3a3afd8df48ad21138c9012404e413
                  0x21a455615b9eeaa2c88dcd3c858c262053f20c884708cf5c57cd40ea61c6981f
                  0xaccfec94e6fc3840997919d9b7b702d229d40246160d3490c7ef296d815e3000
                  0xc15bf33924e06dbcb807191eda64911e797dc6234b92c3c0765011433a4bdc3c))
                (f
                 (0xb084985fe67fd8e35341d8e17b0735bf359de8004c19f19396300e602eb29f1a))
                (sigma1
                 (0xcad405c65cbaf1e1599dd2d4cb85b727bc8a9004aff4cbe43764de3432acea1f))
                (sigma2
                 (0xa0e5b53d2e3c23f4e3cfd5014fc77049189535be0d06eee3d3b8c22ec9e37230)))
               ((l
                 (0x9362e8897f336192d5eb56b6b724e292d817bc654431fee3026acc86eea2ed1b))
                (r
                 (0x60d2550c86e88fb14d8c256c1170947cb800aba4faed13c9eb1fe680553c5427))
                (o
                 (0x78507c309832cc3590eeac5a5422fd3d6e99336b305f6ac6aa314b87fbc0441e))
                (z
                 (0xaeb7c428cbf665e78ee73b96b94d46887e34b7d1b0e316622030cad98c5ac630))
                (t
                 (0xf714e24eee5a4d7cb2108679cf4a687bfae32b07af250f26749da096591f4c00
                  0x5d1e96001e31f61c58ce774ad0a9d60a02288553d9cd6721056315a15d8fb30e
                  0x738ef923deb124691de858faa8b577567b870b1d08b1c4bd5129e5eb15e2c305
                  0x97c3788d10a62742669f341a45ca0a7ca8a39199c1ad0219264fd1336805c904
                  0xd696d86b3f4637c7888416a2afa0ee60965a2fd3e74f6b0f8777d40cb1f2163b))
                (f
                 (0xe7295abc272ebe2f98ba9de85d249ffff04ce470c396a701a342cc7898810609))
                (sigma1
                 (0x67895be354bdbb26c777d3a6f8f530487d16da905750043925f02487b7aa752d))
                (sigma2
                 (0x7469fc9ef5dc7a7739fef0d94450fbdeab1d93d57437897008125f77aa5faa22))))))))))))))
    (two
     (((data
        ((body
          ((pk B62qjHHxCpHgCUAPs9YQ6ofSgF3dwM1Eo9exQ19N53mRTSCLdSZcmFD)
           (update
            ((app_state (Keep Keep Keep Keep Keep Keep Keep Keep))
             (delegate Keep) (verification_key Keep) (permissions Keep)))
           (delta ((magnitude 10000000) (sgn Pos)))))
         (predicate ())))
       (authorization ()))))))))|sexp}

let spec =
  Sexp.of_string_conv_exn
    "(Transition((source \
     6849566483661890759592591293846854705082512508112775365671089561179979967093)(target \
     13694532229185172475580356692973493850727350503839095127148255636530085272827)(supply_increase \
     0)(pending_coinbase_stack_state((source((data \
     17266835387932127082822238518899215645423145017462664247465877438180832058141)(state((init \
     0)(curr \
     15007936336560704945466939094986267772088833227922807959047231327712522037148)))))(target((data \
     17266835387932127082822238518899215645423145017462664247465877438180832058141)(state((init \
     0)(curr \
     3735463824569079414141546435321419519467581190652576408645187649768172539234)))))))(fee_excess((fee_token_l \
     1)(fee_excess_l((magnitude 10100000)(sgn Pos)))(fee_token_r \
     1)(fee_excess_r((magnitude 0)(sgn Pos)))))(next_available_token_before \
     2)(next_available_token_after \
     2)(sok_digest()))(Command(Snapp_command(Proved_empty((token_id \
     1)(fee_payment())(one((data((body((pk \
     B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8)(update((app_state(Keep \
     Keep Keep Keep Keep Keep Keep Keep))(delegate Keep)(verification_key \
     Keep)(permissions Keep)))(delta((magnitude 20100000)(sgn \
     Neg)))))(predicate((self_predicate((balance Ignore)(nonce \
     Ignore)(receipt_chain_hash Ignore)(public_key Ignore)(delegate \
     Ignore)(state(Ignore Ignore Ignore Ignore Ignore Ignore Ignore \
     Ignore))))(other((predicate((balance Ignore)(nonce \
     Ignore)(receipt_chain_hash Ignore)(public_key Ignore)(delegate \
     Ignore)(state(Ignore Ignore Ignore Ignore Ignore Ignore Ignore \
     Ignore))))(account_transition((prev Any)(next Any)))(account_vk \
     Ignore)))(fee_payer \
     Ignore)(protocol_state_predicate((snarked_ledger_hash \
     Ignore)(snarked_next_available_token Ignore)(timestamp \
     Ignore)(blockchain_length Ignore)(min_window_density \
     Ignore)(last_vrf_output())(total_currency Ignore)(curr_global_slot \
     Ignore)(global_slot_since_genesis \
     Ignore)(staking_epoch_data((ledger((hash Ignore)(total_currency \
     Ignore)))(seed Ignore)(start_checkpoint Ignore)(lock_checkpoint \
     Ignore)(epoch_length Ignore)))(next_epoch_data((ledger((hash \
     Ignore)(total_currency Ignore)))(seed Ignore)(start_checkpoint \
     Ignore)(lock_checkpoint Ignore)(epoch_length \
     Ignore)))))))))(authorization(Proof((statement((proof_state((deferred_values((plonk((alpha(Scalar_challenge(bb3b1a937deefb70 \
     f4b6266b324d3d5e)))(beta(716c58af191f6539 \
     453ac33dc7c2cf57))(gamma(9bf803b17ad8b007 \
     14543f29cb40a93a))(zeta(Scalar_challenge(ee54d450c856a6e0 \
     50b63cff5e968933)))))(combined_inner_product(Shifted_value \
     0x4739e4cdda821448be05df0583f471d88393b3248e90aeea9a45d8c4bd3afd00))(b(Shifted_value \
     0xaf769c07b057fcab91d2e3261639d7e7e6b07fd34367134d3423ac673313e322))(xi(Scalar_challenge(9350496ac729bd00 \
     79949fb1bb03918e)))(bulletproof_challenges(((prechallenge(Scalar_challenge(c4ec454e51dc345a \
     1427ac6664705ace))))((prechallenge(Scalar_challenge(3fd26bfdaf54e4ff \
     b93767cd5beaf2ba))))((prechallenge(Scalar_challenge(2530d10cc401b2a9 \
     6bd794f26c7c4027))))((prechallenge(Scalar_challenge(90bf9134e54ffee7 \
     7d720d828e722942))))((prechallenge(Scalar_challenge(3dc1d44cf20d7703 \
     170133e98ce53fd3))))((prechallenge(Scalar_challenge(b6759062af78db99 \
     1eea1c2b56ee9bd6))))((prechallenge(Scalar_challenge(a035111cd5884f0d \
     32f63a66b17d92b0))))((prechallenge(Scalar_challenge(2a5c92df60d67369 \
     1a1e3b1a8fd7de23))))((prechallenge(Scalar_challenge(65187adc7f93e8b0 \
     cab967ea85dc15fc))))((prechallenge(Scalar_challenge(515c0a1681a6bd5e \
     46e614efbfd57e4b))))((prechallenge(Scalar_challenge(c1251c9d82143180 \
     582959fcbac3814a))))((prechallenge(Scalar_challenge(81731d046490cb9b \
     9d5013f66f6987b4))))((prechallenge(Scalar_challenge(79d6e8810b3cb5dc \
     756a51ced4c981e6))))((prechallenge(Scalar_challenge(97253e31a6c45f1a \
     1b4a4f023212dd28))))((prechallenge(Scalar_challenge(5fb870d5d18d5f83 \
     a799967e98defe4d))))((prechallenge(Scalar_challenge(94c9b4aa62ae6312 \
     43d2cbf189443e48))))((prechallenge(Scalar_challenge(a93c31b16d195500 \
     d0b5f4b25b07869c))))((prechallenge(Scalar_challenge(2b3ed2031f25ef1f \
     dbade298e3047fef))))))(which_branch\"\\000\")))(sponge_digest_before_evaluations(8072c6399fb81f02 \
     8b46997a19901e23 48fa2a7e3655611f \
     14d9bd4f7ea353c9))(me_only((sg(0x94df1449fae11f69576145930fa3cc2be0f8d7f51c1c361d64b8b4b4e1431125 \
     0x81a77e7ef86d37398cbb1897f89a7c2cf788bc6f046a67e204e757464cf7e106))(old_bulletproof_challenges((((prechallenge(Scalar_challenge(c670b712b8317513 \
     1675cc339a483e08))))((prechallenge(Scalar_challenge(48c1b0a2b1cab8d1 \
     1b6604e3c071b1ce))))((prechallenge(Scalar_challenge(3382b3c9ace6bf6f \
     79974358f9761863))))((prechallenge(Scalar_challenge(dd3a2b06e9888797 \
     dd7ae6402944a1c7))))((prechallenge(Scalar_challenge(c6e8e530f49c9fcb \
     07ddbb65cda09cdd))))((prechallenge(Scalar_challenge(532c59a287691a13 \
     a921bcb02a656f7b))))((prechallenge(Scalar_challenge(e29c77b18f10078b \
     f85c5f00df6b0cee))))((prechallenge(Scalar_challenge(1dbda72d07b09c87 \
     4d1b97e2e95f26a0))))((prechallenge(Scalar_challenge(9c75747c56805f11 \
     a1fe6369facef1e8))))((prechallenge(Scalar_challenge(5c2b8adfdbe9604d \
     5a8c718cf210f79b))))((prechallenge(Scalar_challenge(22c0b35c51e06b48 \
     a6888b7340a96ded))))((prechallenge(Scalar_challenge(9007d7b55e76646e \
     c1c68b39db4e8e12))))((prechallenge(Scalar_challenge(4445e35e373f2bc9 \
     9d40c715fc8ccde5))))((prechallenge(Scalar_challenge(429882844bbcaa4e \
     97a927d7d0afb7bc))))((prechallenge(Scalar_challenge(99ca3d5bfffd6e77 \
     efe66a55155c4294))))((prechallenge(Scalar_challenge(4b7db27121979954 \
     951fa2e06193c840))))((prechallenge(Scalar_challenge(2cd1ccbeb20747b3 \
     5bd1de3cf264021d)))))(((prechallenge(Scalar_challenge(c670b712b8317513 \
     1675cc339a483e08))))((prechallenge(Scalar_challenge(48c1b0a2b1cab8d1 \
     1b6604e3c071b1ce))))((prechallenge(Scalar_challenge(3382b3c9ace6bf6f \
     79974358f9761863))))((prechallenge(Scalar_challenge(dd3a2b06e9888797 \
     dd7ae6402944a1c7))))((prechallenge(Scalar_challenge(c6e8e530f49c9fcb \
     07ddbb65cda09cdd))))((prechallenge(Scalar_challenge(532c59a287691a13 \
     a921bcb02a656f7b))))((prechallenge(Scalar_challenge(e29c77b18f10078b \
     f85c5f00df6b0cee))))((prechallenge(Scalar_challenge(1dbda72d07b09c87 \
     4d1b97e2e95f26a0))))((prechallenge(Scalar_challenge(9c75747c56805f11 \
     a1fe6369facef1e8))))((prechallenge(Scalar_challenge(5c2b8adfdbe9604d \
     5a8c718cf210f79b))))((prechallenge(Scalar_challenge(22c0b35c51e06b48 \
     a6888b7340a96ded))))((prechallenge(Scalar_challenge(9007d7b55e76646e \
     c1c68b39db4e8e12))))((prechallenge(Scalar_challenge(4445e35e373f2bc9 \
     9d40c715fc8ccde5))))((prechallenge(Scalar_challenge(429882844bbcaa4e \
     97a927d7d0afb7bc))))((prechallenge(Scalar_challenge(99ca3d5bfffd6e77 \
     efe66a55155c4294))))((prechallenge(Scalar_challenge(4b7db27121979954 \
     951fa2e06193c840))))((prechallenge(Scalar_challenge(2cd1ccbeb20747b3 \
     5bd1de3cf264021d)))))))))))(pass_through((app_state())(sg())(old_bulletproof_challenges())))))(prev_evals(((l(0x055ffb64b256a2c46154479a1dc99aafa8bb42b49ca86dda1243b14a37c1e11c))(r(0xc8d5a67880ad5a41456b62d50fa46e36083e5c70803b615e496c84ee0420db10))(o(0x851a1187c7fcf2e7c450db995a643f141bbe67c96bfb7384d3ca333e3d39a41f))(z(0x1990109117e13ba8b54dbeac5beae50b5d1c5a637230ecbcd75129b257d67b06))(t(0xc15f3cf60e672fd67b9641f628dedf3e62ee60ea70fc72b31fb71e5b03c78119))(f(0xfdab70b4686e3e058f81e4439c4ae39fb169668a024225a95ef5a4bd1681641c))(sigma1(0x62813ab9da17fe1e116fd22a2f26f6a029cd1b8b4c17cdea1bf4365daf019607))(sigma2(0x42483f4475c1a5ed2918b1343bf8632c47c583e3f5d064119f76cae63e647e13)))((l(0x845f8312a2547307c55d374471c7aec113486d2754376c5e072e860df2010032))(r(0xd92c31032bfb10cd9d0798f10a3b9c2f3168f91b6985c35a9a5e026106574933))(o(0xb97232319db06cd27540f11be29eee80efe18f5c2969d3f7ae0551b7745e9303))(z(0xea18701cd14bb3db37ac5129d9cdf321499c526ce81b7c3000b28b1ab289c922))(t(0xcb282638863a0b411b36c7a193bbb7f858fd9fe9fb9fcf928e60f82df5769011))(f(0x2b6fa38461595be7222b5c8a761e0a264ec52f3aaf5ef18d3d8f3315fc136006))(sigma1(0x4e5a517da5e85e8e7436ec517eb5b29fa477bd6acad92a89d982728fa3052a3f))(sigma2(0x8ae5e22f7d2bf24ca3aef95fe1424e9718a630b7499d9785c91c9b59d06b3126)))))(prev_x_hat(0x37e0109ef627ff2be3d54e7e68ef9aac7e9a38bfb2d44503426392077fec2f0f \
     0x5c7919bff13ce8c2bc2be3beb71f826a496c4e3dd823d402b7d032a0c690761a))(proof((messages((l_comm((0x533b37bda82a269f8eea7769f2ee9ef23eda5f685e4c0ee177a4577caa22bb21 \
     0xc0c25136d2655fe11d60c6d3f1e45783fece69e504f3ad7ec95717f4add7a305)))(r_comm((0x5ae5c78a0917203932bd5c0c081b80977f11cceb4d2913884149efec16b0be1a \
     0x82cf950dc49d4c5f2af50f5806a58ea4d2e808da4974cc2661799fbcf4030c08)))(o_comm((0xcc117091224ff323afe7201e542424ceb5af36aa68d5f5a966706ecc97e7160f \
     0x80894b12cc0bbf9859a1d3f430c4bd740f1ed72e3dd866a2b10de5bc531f4a18)))(z_comm((0xbbb01edb74b7dcd952df2ec0184187e772783d4b380a67350c0695d3f06cbd22 \
     0x011d56a7a98db52625fda704b1e67fad40580d16d44dd977b9ad45899dfdfa06)))(t_comm((unshifted((Finite(0x0df7f2ce2af2c3144505e496691a66498991f3cf4bbd9386bc17b05f48cf7300 \
     0xb76b2d95ff5d9b3ec291641f487d29a107f54925bcd66f9257c22c40dedcbb30))(Finite(0xd4f8c14e6cfed9a08df93167db32696b4306c385671c26ec5db77087f6a9ed0f \
     0x91f631b6028693f0075ee6880c5661103df3e92a4e1ba484ebada4c2cc206904))(Finite(0x1734edf224fe27f6666320d36c57908557233e5e4de468292c9ea970193b2a32 \
     0x903ec08fe8a56e40d68a54d6adf2b0e01f7524af78f99fd9ab19251dbc076920))(Finite(0x8a4b2e610397f5ae3b0624f1fbb3ccd27322b47482599fac9417d468f4fdfc09 \
     0x37fbdd60cf3499c46464d2816661493587ca6914af09c89564379098df993a35))(Finite(0x93536ad23a2f834ef2ef58921ad6f841dde3f5694d9a0fb593dbbb05ce6b4e0c \
     0xc11b05eda232d020dfd339fd31b6c294e55bd4c112c114ae8a38faf8478fde00))))(shifted(Finite(0xb6dd6116bfcadce30626e8cc303724ca41ca931ef0a69d2552aaf30969065505 \
     0xd994354f278f259f4d0850ffb7e145a39b0437f54041c3eaf10777c87ee37302)))))))(openings((proof((lr(((0xdbbf4609431fdc587f96a84657aef1232e0c47c56af26093b20df77cb148c929 \
     0x478623fd73e8ffe8907867e1cc1891be0731e11ac02b59802e206fce6afd9328)(0x37431ef25f7465dfe32f67e9ac776dc7fbbe8530b80828b7b93246578a5f5c3c \
     0xb08dec05a8a0c13a3dc38d55d800d21a491475133d1c9a176b4df761cd371111))((0x21dfdcef6c5122d48db26d714dfb6032d33461952dffd67e1fbdf7804ae2a837 \
     0x7bb2a3859555258e33c427800dd3d94b290b234e93f9995e733c89dabb628a16)(0x2aef955fd5761e9e8c0fea64425a94a2a7a9cab08a86b6d8e11c116c7d02400d \
     0xa0a4fd50507f004568b8b6cdc3acffab3b77163f2f02c82363487e625e2ab435))((0xdc7fbfedd10fbc5a313d5c9f6f1db0773eaa1ba4f6947fd5ff131c0a0ece3810 \
     0xef3499a61a8eac274a635fe10b10ec14819c36c217bd77258f3749055afb0738)(0xd73f3c15e0d2acb80382d003d12300a070b3b7afe943200045ed774521006b10 \
     0x330e387aedaf2314cad627debde1f4433553f8db072d45a1233052c887adf73e))((0x2f0f79b7e50b4b4a87598770ed569586bde82b1983a7a16559af6ddbfcdd6718 \
     0x9a4ab98031aafb342fcfe232148cdf62e51fb7d12dc6722ae82a01aad7b0d612)(0x0e100c0a29fced02d0432cfb92f6edb0f0edce33715d476b37ded55f3131643c \
     0x55653a6be2007545395bbc974f1a399e0226225d2df944015232640392681616))((0xd3435921fa6a9e08249590c8968aca3c2c8eb499b1271c5890627e0c6397750a \
     0x0769eddfc2d9f07b2a8be0f277133203de96edadf85006e3b26479d97f8d2303)(0xc6b9d9ccf13e550e52437e23c43e71b19269f983b7f7a245a6068a17abdb4733 \
     0x209c3f748ddfc3af96b52abfbc795b755a66c6fdf3e539c18698d5f798f79727))((0x93746509ca908fbf4db2c30b973e352d36dd4ca53bdeb5bc0bb2cf5cfd220409 \
     0x0e33cf04d4bd5d1a57b86b11dc4759db1634eb7756cb1aa96560eb9cb1115408)(0xb60908a386e134a4727272d26b8488a85cf2965b8753f7889a892ca7b47aa319 \
     0x6d4629c1ac3a6bc6ed341c4ed42eaba9cde2ec90a647b436828ae161ec627103))((0x6579845ff43164ed0646f424ef66f786b5b905532fdfac5bf60664d710029a2f \
     0x30ac847e0324ed899031121fc6dd1a311eff41ac0b72c5f5eff10b0fc911263d)(0x317139f4c37908e38de9e07cedb849ac2706ba71ef6252287ee5a149ba031d0c \
     0x09897bbe64a441bf9d663e079d8d71a1c064f36a3afcba475e5f4eb838b3dc31))((0x38e0377c3b8cc2672368ba66d5c76b2f1662dde532307d1ed9ab2e6e61574a27 \
     0x4fffac659a2c80d171cf483d91cca16be35d2d1c9ab722b7858dff10176ee429)(0xa5a99e3600ab46be77ba73b332955fc1383935ce23fafbb5003f1e9c15d3a82f \
     0x27747f370c9fa5260a4ca458e0029ee43407524f8a47d4fcf29f3852e43e492a))((0x3743d5ea0d2d87071c1fccd8afe8241bc056178b0077fb0c9238d7ea4169d129 \
     0xd1fafb1bd06b63a1df2b356e7daa4092969c87b8a8b086e7201713128271bd12)(0x5920e95d8ba0f1b17f7be5cc37fd07f1d90b4a71a72cd09bf29e952436357a33 \
     0x343665bfd094e50e7ac03723d184dd807fbda6cb5aa098e0bb158e76b11f2e3f))((0xa4f081ca1339aacb7b1b1dbf9fce31542e2f519c5c37d11b8f762bfe8da0a926 \
     0xbf870c724d947ae5e5d08fbab7e060b4f860051936417b2af2dd124bd6739f07)(0xd18378f3aa2f0032c9cb899a92d041c954ecf7b070eec528cb8fb16688985536 \
     0xc9dfafacb91fd8b1d50d7c3624d54cf8712f0457cc4d3d19bf0b32a0e22be53f))((0x32c4cc0962c7bddb011dcdd97dd059271ce69146f120ef74e514682310bc513a \
     0xfb2fd032ef48f7493abd5314ddf5d6e9dccdb7163fbb288538ffbde3d07a8c1d)(0x1c21e62009d7115a5b06ef55af4c8e02b241d0e4eb572a478276a06612d3463e \
     0xdb649c20d95606ca6605ac42cb3e4434ce0aa9e5320e1739b259bb99796a413a))((0x4b8ee80ede1c859578966ac3f49a00a0b9fd35f9b7d835588efd1307e5bd1d0c \
     0x509225e6e86d8edb5f901e2874f640df124ffc9e6fbef666c1201dca1659c50e)(0x3b964942584aeeed3df7d33f65c48691f2104f1af61a7b8927e5018cdcb67317 \
     0x2331ab337378810e9ef44ab00246855582eaae87336bfdea00ce0b710f3dde03))((0x8803463c438c6c9515e0561e68c076d2e292dfd57a0f6900080ddde1e7026d07 \
     0x1106821fd689cc92bfd854ee3902f0b58f810e605af85568efa035b3d4a89905)(0xaa208628adacadff360819335fa57e2b4999a986239e0e47a5087dee1bd6ca21 \
     0xbf84c01dbf92048e9351196a6da794df78342d89fa4647ace098086a30958425))((0x5f0d333e97e15f149dcb8fd493a69e0bc8df8cf0badc88096325c0a046c0e617 \
     0x132fb2b82f6a5c5ea00527ca320f3a26e7ff9d06952ca9afbe1acddf8d2e843a)(0x7b3b30ab242182f896a43e75d983314b2c0676dc6b728b01e58cbab7a7667d24 \
     0x97e4753382c98a40520d8e960012f13a801631aa88aa739ca605ea5719906804))((0xc353c02ad43291e7974b9bbe7714b3e789216e6facb967619b657aa45d8b722f \
     0xc68285df7a2e004896f50c89c87f56bf44562f70ec717133ce441ed6ec95142e)(0x3d50d434e54eaf846eeffdcacb9316e89e796aa45dab79b7198556c28f0a083e \
     0xd6efd6e3c1072e4f618f80dd9e07f7a12f481581a86b96a50c2d34b3f3058001))((0xc1a64cdffa1db03ca3f20258e0c6c2749cab6b3057ec9c6fac6593ca746e1013 \
     0x26c347164ea335a1e46b70a26c49d8d873b65d37c82d0ca1e7607f1768f05638)(0x5e53cd48d6867f4e08f0599b6e232254758dad5ec16357801c91e3adc2867c1f \
     0xd0076a2fc8ffe964255b1c92cfc7ea955f761de082d497f2712bde7aa134f100))((0xe463c84e7903206278c851c641e3a7a16584dd8fb5421bafa266c4c9a085ba0e \
     0x5127fd7046672f1ab988e1c38d243920fcb171ac2c709b6976778f72b1886018)(0x84ce03b6c564863819ba3a9de4e1963755e536cf8bc77384b68e6fa8bb58523a \
     0x683ed9da76fc31335293ed39f80816c573ba07007160b59b70112f7e462bc100))))(z_1 \
     0xcf00c9ca707ec5fd5241057c222c8906f2a71f9f4cdd6ff088a51aa1d08fff2a)(z_2 \
     0x58e688a89abbaef8b39cbc9b0e3dcecc010b08a83b5955e34bef8d251d0f2d35)(delta(0xc0f11f55803b644c54f8605a69821758527bdaa23fcd7976a55030396ef95607 \
     0x3df08f99a26110f314c9d9bc624df4aad5504a2b79d61351238accc262087b3d))(sg(0x4461df955a50c0b15b5665af514846b4286990ddc816b8a7c39f9c07aedf0939 \
     0x8b1ca22380b70418aaeca660ff31c1b298ca8b0f696727c7a40bbc8815e7eb29))))(evals(((l(0x36049d918dfb0879207b6fc04598944aa812e25e7497efc7b4307eed72583e37))(r(0x21f23734064b4c2f5d5bf153fdf9778dfec364cb6dc49a70f3242016890d2b30))(o(0xa0d43c08e14a10819fc0c36afdea4599763bca6adebe69251a6f37c2ae8efb0a))(z(0x6c868fc3ecff002b668bb8bccf803d64b9d31fa6edb8436953954777a906a22a))(t(0x7957549cbc872505a207725a295657da453319bd8337c2a3a6eef14e5b256f12 \
     0xab98b107df0e56d6ab23089264ad33b18f3a3afd8df48ad21138c9012404e413 \
     0x21a455615b9eeaa2c88dcd3c858c262053f20c884708cf5c57cd40ea61c6981f \
     0xaccfec94e6fc3840997919d9b7b702d229d40246160d3490c7ef296d815e3000 \
     0xc15bf33924e06dbcb807191eda64911e797dc6234b92c3c0765011433a4bdc3c))(f(0xb084985fe67fd8e35341d8e17b0735bf359de8004c19f19396300e602eb29f1a))(sigma1(0xcad405c65cbaf1e1599dd2d4cb85b727bc8a9004aff4cbe43764de3432acea1f))(sigma2(0xa0e5b53d2e3c23f4e3cfd5014fc77049189535be0d06eee3d3b8c22ec9e37230)))((l(0x9362e8897f336192d5eb56b6b724e292d817bc654431fee3026acc86eea2ed1b))(r(0x60d2550c86e88fb14d8c256c1170947cb800aba4faed13c9eb1fe680553c5427))(o(0x78507c309832cc3590eeac5a5422fd3d6e99336b305f6ac6aa314b87fbc0441e))(z(0xaeb7c428cbf665e78ee73b96b94d46887e34b7d1b0e316622030cad98c5ac630))(t(0xf714e24eee5a4d7cb2108679cf4a687bfae32b07af250f26749da096591f4c00 \
     0x5d1e96001e31f61c58ce774ad0a9d60a02288553d9cd6721056315a15d8fb30e \
     0x738ef923deb124691de858faa8b577567b870b1d08b1c4bd5129e5eb15e2c305 \
     0x97c3788d10a62742669f341a45ca0a7ca8a39199c1ad0219264fd1336805c904 \
     0xd696d86b3f4637c7888416a2afa0ee60965a2fd3e74f6b0f8777d40cb1f2163b))(f(0xe7295abc272ebe2f98ba9de85d249ffff04ce470c396a701a342cc7898810609))(sigma1(0x67895be354bdbb26c777d3a6f8f530487d16da905750043925f02487b7aa752d))(sigma2(0x7469fc9ef5dc7a7739fef0d94450fbdeab1d93d57437897008125f77aa5faa22))))))))))))))(two(((data((body((pk \
     B62qjHHxCpHgCUAPs9YQ6ofSgF3dwM1Eo9exQ19N53mRTSCLdSZcmFD)(update((app_state(Keep \
     Keep Keep Keep Keep Keep Keep Keep))(delegate Keep)(verification_key \
     Keep)(permissions Keep)))(delta((magnitude 10000000)(sgn \
     Pos)))))(predicate())))(authorization()))))))))((ledger((indexes(((B62qjHHxCpHgCUAPs9YQ6ofSgF3dwM1Eo9exQ19N53mRTSCLdSZcmFD \
     1)3)((B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8 \
     1)2)))(depth 20)(tree(Node \
     6849566483661890759592591293846854705082512508112775365671089561179979967093(Node \
     6359171007834024020792043921671759986138576255573031014184785296968609395978(Node \
     10982230421580437975718528557088832319796787931174107439847420794233653768708(Node \
     10801895127722884671862334078365237166154898270368821670513152669470992538745(Node \
     6067260237180049614418680658932414783737942457159343135980092662612516436834(Node \
     5588425164203293751766164185418987168782378563096302471792058529551239413586(Node \
     17885959275673686449868058792252848376370571919122962712082280844535809424741(Node \
     12846990074735183779373456249625331633942218775861207017406746839799590774687(Node \
     26856234343472494684517718493374580706185078781520287613759301666642747864814(Node \
     8855425608903141177809339085473527131366972244798976836553488844999744945298(Node \
     10634068816438820354829141290700657596903633721488940319662658983163494263655(Node \
     6582080099115900974538595922109892148677767304870488617270043183081038069263(Node \
     3818183244705333185373336476045008323824677024834841937831540842678799898256(Node \
     9487070563631692827875304561287450396939969554003683964293956467574073783827(Node \
     13046182460429048147507267295261212992417996149094703672196629133789441615029(Node \
     19940913343115436045982854779372029600010114896583398588257644923615921484343(Node \
     12383477161809538814709069568410370273491038838232913167475668175370281186094(Node \
     27582022074903544874771773321600490113907818027676198095936944164420287057989(Node \
     7259545543840619572754022849863147838246331754113614824001044915762599630680(Hash \
     25735488456711348155847978080870884834406100331956253065917907273670499091043)(Node \
     14759277725212845146292455161025901851575938451752076128129704914206453702945(Account((public_key \
     B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8)(token_id \
     1)(token_permissions(Not_owned(account_disabled false)))(balance \
     100000000)(nonce 1)(receipt_chain_hash \
     3146476405680824843388338687607969347758293027116133486788781494788122096032)(delegate(B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8))(voting_for \
     0)(timing Untimed)(permissions((stake true)(edit_state Signature)(send \
     Either)(receive None)(set_delegate Signature)(set_permissions \
     Signature)(set_verification_key \
     Signature)))(snapp(((app_state(0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000 \
     0x0000000000000000000000000000000000000000000000000000000000000000))(verification_key(((data((step_data((((h(Pow_2_roots_of_unity \
     14)))\"\\000\")(((h(Pow_2_roots_of_unity \
     18)))\"\\002\")))(max_width\"\\002\")(wrap_index((sigma_comm_0((0xc68c27c053af0253e0766d78dee279549327e34cf4712c69b6119d5b0b056632 \
     0x857095e4bb2ba0527eba20aa03ae6bc83f63736ebe6807e4ce5b564c1395cc3b)))(sigma_comm_1((0x3a01b8de00402a9a1d20d30003057dccce2617179209368ea4b154d5e52b041b \
     0xd4d893dc762724a667af55b0f1ca476e0573929787169e18c8d66acb7ee10b36)))(sigma_comm_2((0x433f9d21850f056aa859fd62954335e557001ac417718c32c5e025eecb770613 \
     0x766ad10c970be400bbcdadc2ab3af2e24695082bf5b2a92073d731e16da84f39)))(ql_comm((0xe70eceb2d53da8b785d27519d085fb9e9b09341d011e2f2e4d8e1c41732b500b \
     0x4b810cfce229cbc1c44f82653288941bad79e4ef8034f05e6c90b3cd54fdab37)))(qr_comm((0xbd8092a7659317af7163de3bdd39698c85a7c9305022dec0ec29d971126ab030 \
     0x0da632a0eb4f29644e18daae0a10f7681472577adf71df7dea7a418cbdd78a38)))(qo_comm((0xae7215fa1bcee04f69eac3ab7edeb8280a365310ddeb12cf335ed17a8eceda20 \
     0x84328cfc0c9d3f1b3e124d06af89f53df3cbd98e1e1531a0a46eebea11875d0b)))(qm_comm((0x4ea2de85336081ce612e8ae72d3d448f7fe04f3e0ca01a79f5c1aeb75ff34312 \
     0xbcb8618fbce302aadd7802aee6f924c21981b8568d143114b22e0d8f8a153a1c)))(qc_comm((0xc5e32541bed7d26a24afec8ae4762167da289f5ade6f9b88c2ce54f1fb01041a \
     0x5922488475b06fcc1b1e4044746dda2df08ac2af8ad3f39c777fb011b90de810)))(rcm_comm_0((0xa1e31a5790505fd3eee5e773e748b1950e914df99118b3f02306064dd9a2e307 \
     0x3167d3e69026113f8a2329dfdfbdd1050436f26b586717113d6a2596df8b9034)))(rcm_comm_1((0x28ef2de79afa5c9748c41deae004cedbb06d140ea0ed3f7b0d67123790b9d600 \
     0x112650ffc2c287b82d786daea22cd6bcdb3b384b689f1ae582fbba9d198db52e)))(rcm_comm_2((0xa6c42a5626e5901f9193b25e467337c0a6f6a2e6f5a8b6ced8b6668896a9c222 \
     0xa39755d210229e76d8067ce5ba7f9c74087b04858124f23341d78f119ed39e2b)))(psm_comm((0xd1f7a9bf154332deadaf4fadff98696e78cba194d6f30363a3f8b2e6e7014138 \
     0x4c9cb919417dc71516132b4116c54d2057736381c9392cf0315995e79446641e)))(add_comm((0xa5cde889023bc121869cccf87800bc396631f812e74762ae3a3d385905ef3616 \
     0x025469cba560fbf9232b3206565a344fe13c3a0e8a64772b27aea94788879f21)))(mul1_comm((0x1fa737069cbd5a813893f1ffd1bf958369f2d6d928d61662af71f3739909903c \
     0xfbfea8725a70b2a1a4ac0f1209a8edc13533eae6bf8341b2b55d6825ba333215)))(mul2_comm((0xf0c910c953fd127ed9594664f723bf0b149a51f4ff90255910afa31480849920 \
     0x59f26c42764d9fa5ae43b42a09ddd264550b1eba9634c3641b2a06a1c8f64122)))(emul1_comm((0x359b1e90f11b5b1135c86a39a380ebe8aa34c6daf644c6b54e75eafdd4290d3c \
     0x6ae2fcae3267b896319d84f69a92d0f9c7e0f749fc118b2fd9991046d9946504)))(emul2_comm((0x82e5b6e7023f0e9ecc9514d709a136537c5d5d8365e0b710448364a465fa6f17 \
     0x16c89c3866bc096923c90c9ae5a1c794ae14df6d47064c869566afa58b32f90c)))(emul3_comm((0xc73d3f3dbb90a4a64b968020c86f9194b34c36a6f8ec91d21dcf0b97236a9a28 \
     0x7897359c770024535f6d4141795ba793852d8654a7a97f17bb97ff1ed7ae620a)))))))(hash \
     0x46a6ba4c307512ee944473bb5decd31179f59e0ce28e8f13d4a7077a58e3313c)))))))))(Account((public_key \
     B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG)(token_id \
     1)(token_permissions(Not_owned(account_disabled false)))(balance \
     0)(nonce 0)(receipt_chain_hash \
     4836908137238259756355130884394587673375183996506461139740622663058947052555)(delegate())(voting_for \
     0)(timing Untimed)(permissions((stake true)(edit_state Signature)(send \
     Signature)(receive None)(set_delegate Signature)(set_permissions \
     Signature)(set_verification_key Signature)))(snapp())))))(Hash \
     25746399379572662543289348217887939692074738631711384108278693924492811716777))(Hash \
     20840111199505614756303544387062483742414767413624503798275950783474893610391))(Hash \
     13686944877975925220832179675000667339068018453373822671858815658092427130669))(Hash \
     9603285567976632451407723959054631516771444785027225998107345882946682851397))(Hash \
     17771475522368793049454927939001730669756639270220442182777565379369079956943))(Hash \
     3626919221200937313622133521030902100472440911378537960341354193259819215875))(Hash \
     28402426036443664210970465238064922956660498450668351484898191754239089636779))(Hash \
     13666503971224077156230930794937075123696844826936395615399070324230773839768))(Hash \
     6278949539543187916688934569346523097221647206366978743882323591206893455546))(Hash \
     15647443512726270449139618973734448878621617827207468595797509890200608138589))(Hash \
     6700842439428085273138474709745613210809706111281755073229779727052791747333))(Hash \
     26750656128016549097535374786343787392687079458313071910813703052665891802349))(Hash \
     19698260728758859667366435691139605346024078389458263175349319766052077377132))(Hash \
     3721670089453178680058934912030697953782806072702818809393636266744600654254))(Hash \
     17381798997516813993772015356910223666668897755515822830623678818500671271685))(Hash \
     13397103328903483128345420411392750383971622193816361472253050845360254398758))(Hash \
     2056502044187082956072967090352194626597447138581172025813930795572945422798))(Hash \
     24115786881741157295119193337161732321895716407890331713944883598293805372071)))(next_available_token \
     2)))(protocol_state_body((genesis_state_hash \
     6941115869822719558052608452633431721222748917164300781770477055207532231790)(blockchain_state((staged_ledger_hash((non_snark((ledger_hash \
     6849566483661890759592591293846854705082512508112775365671089561179979967093)(aux_hash\"\\128\\151X%e \
     \\127\\159o\\221C\\180\\133\\246\\179\\180\\140$\\021D\\177\\140M\\196\\193\\156!(:a\\217G\")(pending_coinbase_aux\"\\147\\141\\184\\201\\248,\\140\\181\\141?>\\244\\253%\\0006\\164\\141&\\167\\018u=/\\222Z\\189\\003\\168\\\\\\171\\244\")))(pending_coinbase_hash \
     28157300470035495279044334150721592342912188756780325261349072331154507582437)))(snarked_ledger_hash \
     12601500461114864746121497696654557453230267406629127404450291094925069968562)(genesis_ledger_hash \
     12601500461114864746121497696654557453230267406629127404450291094925069968562)(snarked_next_available_token \
     2)(timestamp 1613965017728)))(consensus_state((blockchain_length \
     15)(epoch_count 1)(min_window_density 0)(sub_window_densities(0 0 0 0 0 \
     0 0 2 0 0 \
     0))(last_vrf_output\"\\021\\188X/WK\\183\\000A\\148\\253I\\165\\024\\019\\011\\0168\\246\\130xC\\136r3\\228RG\\234\\202\\217\\004\")(total_currency \
     66000000001000)(curr_global_slot((slot_number 7751)(slots_per_epoch \
     7140)))(global_slot_since_genesis 7751)(staking_epoch_data((ledger((hash \
     12601500461114864746121497696654557453230267406629127404450291094925069968562)(total_currency \
     66000000001000)))(seed \
     24221789077120213959039111069021501449922587772317690964568331177935418785573)(start_checkpoint \
     0)(lock_checkpoint \
     10035595115946155288311478115448832385138541039487270516432654510622167719663)(epoch_length \
     2)))(next_epoch_data((ledger((hash \
     12601500461114864746121497696654557453230267406629127404450291094925069968562)(total_currency \
     66000000001000)))(seed \
     12362146314523024880039150583282043615482163879644860802157840874961962346443)(start_checkpoint \
     6941115869822719558052608452633431721222748917164300781770477055207532231790)(lock_checkpoint \
     21376566633863639392589109671506514733324735642463316587307876856544458184371)(epoch_length \
     14)))(has_ancestor_in_same_checkpoint_window true)(block_stake_winner \
     B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV)(block_creator \
     B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV)(coinbase_receiver \
     B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV)(supercharge_coinbase \
     true)))(constants((k 290)(slots_per_epoch 7140)(slots_per_sub_window \
     7)(delta 0)(genesis_state_timestamp 1613499926667)))))(init_stack((data \
     17266835387932127082822238518899215645423145017462664247465877438180832058141)(state((init \
     0)(curr \
     15007936336560704945466939094986267772088833227922807959047231327712522037148)))))(status(Applied((fee_payer_account_creation_fee_paid())(receiver_account_creation_fee_paid())(created_token()))((fee_payer_balance())(source_balance())(receiver_balance()))))))"
    Snark_worker.Work.Single.Spec.t_of_sexp

let test =
  let main () =
    let constraint_constants =
      (Lazy.force Precomputed_values.compiled).constraint_constants
    in
    let%bind.Async worker =
      Snark_worker.Prod.Inputs.Worker_state.create ~constraint_constants
        ~proof_level:Full ()
    in
    let open Mina_base in
    let%bind.Async _ =
      let open Async in
      Snark_worker.Prod.Inputs.perform_single worker
        ~message:
          (Sok_message.create ~fee:Currency.Fee.zero
             ~prover:
               (Signature_lib.Public_key.Compressed.of_base58_check_exn
                  "B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8"))
        spec
      >>| Or_error.ok_exn
    in
    let directory_name = "/tmp/mina-db" in
    Unix.mkdir_p directory_name ;
    let accounts =
      Fn.flip Sexp.of_string_conv_exn [%of_sexp: Account.t list]
        {sexp|(((public_key B62qiTKpEPjGTSHZrtM8uXiKgn8So916pLmNJKDhKeyBQL9TDb3nvBG)
  (token_id 1) (token_permissions (Not_owned (account_disabled false)))
  (balance 0) (nonce 0)
  (receipt_chain_hash
   4836908137238259756355130884394587673375183996506461139740622663058947052555)
  (delegate ()) (voting_for 0) (timing Untimed)
  (permissions
   ((stake true) (edit_state Signature) (send Signature) (receive None)
    (set_delegate Signature) (set_permissions Signature)
    (set_verification_key Signature)))
  (snapp ()))
 ((public_key B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8)
  (token_id 1) (token_permissions (Not_owned (account_disabled false)))
  (balance 100000000) (nonce 1)
  (receipt_chain_hash
   3146476405680824843388338687607969347758293027116133486788781494788122096032)
  (delegate (B62qoseJ6kKvAcavdp4RqWqYDPuDeaJQuiQ5JKafdzwVw66ujnWqFK8))
  (voting_for 0) (timing Untimed)
  (permissions
   ((stake true) (edit_state Signature) (send Either) (receive None)
    (set_delegate Signature) (set_permissions Signature)
    (set_verification_key Signature)))
  (snapp
   (((app_state
      (0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000
       0x0000000000000000000000000000000000000000000000000000000000000000))
     (verification_key
      (((data
         ((step_data
           ((((h (Pow_2_roots_of_unity 14))) "\000")
            (((h (Pow_2_roots_of_unity 18))) "\002")))
          (max_width "\002")
          (wrap_index
           ((sigma_comm_0
             ((0xc68c27c053af0253e0766d78dee279549327e34cf4712c69b6119d5b0b056632
               0x857095e4bb2ba0527eba20aa03ae6bc83f63736ebe6807e4ce5b564c1395cc3b)))
            (sigma_comm_1
             ((0x3a01b8de00402a9a1d20d30003057dccce2617179209368ea4b154d5e52b041b
               0xd4d893dc762724a667af55b0f1ca476e0573929787169e18c8d66acb7ee10b36)))
            (sigma_comm_2
             ((0x433f9d21850f056aa859fd62954335e557001ac417718c32c5e025eecb770613
               0x766ad10c970be400bbcdadc2ab3af2e24695082bf5b2a92073d731e16da84f39)))
            (ql_comm
             ((0xe70eceb2d53da8b785d27519d085fb9e9b09341d011e2f2e4d8e1c41732b500b
               0x4b810cfce229cbc1c44f82653288941bad79e4ef8034f05e6c90b3cd54fdab37)))
            (qr_comm
             ((0xbd8092a7659317af7163de3bdd39698c85a7c9305022dec0ec29d971126ab030
               0x0da632a0eb4f29644e18daae0a10f7681472577adf71df7dea7a418cbdd78a38)))
            (qo_comm
             ((0xae7215fa1bcee04f69eac3ab7edeb8280a365310ddeb12cf335ed17a8eceda20
               0x84328cfc0c9d3f1b3e124d06af89f53df3cbd98e1e1531a0a46eebea11875d0b)))
            (qm_comm
             ((0x4ea2de85336081ce612e8ae72d3d448f7fe04f3e0ca01a79f5c1aeb75ff34312
               0xbcb8618fbce302aadd7802aee6f924c21981b8568d143114b22e0d8f8a153a1c)))
            (qc_comm
             ((0xc5e32541bed7d26a24afec8ae4762167da289f5ade6f9b88c2ce54f1fb01041a
               0x5922488475b06fcc1b1e4044746dda2df08ac2af8ad3f39c777fb011b90de810)))
            (rcm_comm_0
             ((0xa1e31a5790505fd3eee5e773e748b1950e914df99118b3f02306064dd9a2e307
               0x3167d3e69026113f8a2329dfdfbdd1050436f26b586717113d6a2596df8b9034)))
            (rcm_comm_1
             ((0x28ef2de79afa5c9748c41deae004cedbb06d140ea0ed3f7b0d67123790b9d600
               0x112650ffc2c287b82d786daea22cd6bcdb3b384b689f1ae582fbba9d198db52e)))
            (rcm_comm_2
             ((0xa6c42a5626e5901f9193b25e467337c0a6f6a2e6f5a8b6ced8b6668896a9c222
               0xa39755d210229e76d8067ce5ba7f9c74087b04858124f23341d78f119ed39e2b)))
            (psm_comm
             ((0xd1f7a9bf154332deadaf4fadff98696e78cba194d6f30363a3f8b2e6e7014138
               0x4c9cb919417dc71516132b4116c54d2057736381c9392cf0315995e79446641e)))
            (add_comm
             ((0xa5cde889023bc121869cccf87800bc396631f812e74762ae3a3d385905ef3616
               0x025469cba560fbf9232b3206565a344fe13c3a0e8a64772b27aea94788879f21)))
            (mul1_comm
             ((0x1fa737069cbd5a813893f1ffd1bf958369f2d6d928d61662af71f3739909903c
               0xfbfea8725a70b2a1a4ac0f1209a8edc13533eae6bf8341b2b55d6825ba333215)))
            (mul2_comm
             ((0xf0c910c953fd127ed9594664f723bf0b149a51f4ff90255910afa31480849920
               0x59f26c42764d9fa5ae43b42a09ddd264550b1eba9634c3641b2a06a1c8f64122)))
            (emul1_comm
             ((0x359b1e90f11b5b1135c86a39a380ebe8aa34c6daf644c6b54e75eafdd4290d3c
               0x6ae2fcae3267b896319d84f69a92d0f9c7e0f749fc118b2fd9991046d9946504)))
            (emul2_comm
             ((0x82e5b6e7023f0e9ecc9514d709a136537c5d5d8365e0b710448364a465fa6f17
               0x16c89c3866bc096923c90c9ae5a1c794ae14df6d47064c869566afa58b32f90c)))
            (emul3_comm
             ((0xc73d3f3dbb90a4a64b968020c86f9194b34c36a6f8ec91d21dcf0b97236a9a28
               0x7897359c770024535f6d4141795ba793852d8654a7a97f17bb97ff1ed7ae620a)))))))
        (hash
         0x46a6ba4c307512ee944473bb5decd31179f59e0ce28e8f13d4a7077a58e3313c)))))))))|sexp}
    in
    let ledger =
      let l = Ledger.create ~directory_name ~depth:20 () in
      List.iter accounts ~f:(fun a ->
          Ledger.create_new_account_exn l (Account.identifier a) a ) ;
      l
    in
    let txn_state_view : Snapp_predicate.Protocol_state.View.t =
      let epoch_data : _ Epoch_data.Poly.t =
        let ledger : _ Epoch_ledger.Poly.t =
          { hash= Frozen_ledger_hash.empty_hash
          ; total_currency= Currency.Amount.zero }
        in
        { ledger
        ; seed= State_hash.zero
        ; start_checkpoint= State_hash.zero
        ; lock_checkpoint= State_hash.zero
        ; epoch_length= Mina_numbers.Length.zero }
      in
      { snarked_ledger_hash= Ledger_hash.empty_hash
      ; snarked_next_available_token= Token_id.default
      ; timestamp= Block_time.zero
      ; blockchain_length= Mina_numbers.Length.zero
      ; min_window_density= Mina_numbers.Length.zero
      ; last_vrf_output= ()
      ; total_currency= Currency.Amount.zero
      ; curr_global_slot= Mina_numbers.Global_slot.zero
      ; global_slot_since_genesis= Mina_numbers.Global_slot.zero
      ; staking_epoch_data= epoch_data
      ; next_epoch_data= epoch_data }
    in
    let sparse_ledger =
      Sparse_ledger.of_ledger_subset_exn ledger
        ( Transaction.accounts_accessed ~next_available_token:Token_id.default
            snapp_command
        |> List.append (Ledger.accounts ledger |> Set.to_list)
        |> List.dedup_and_sort ~compare:Account_id.compare )
    in
    let ledger_pre = Ledger_hash.to_base58_check (Ledger.merkle_root ledger) in
    let accounts iter =
      let acs = ref [] in
      iter ~f:(fun _ a -> acs := a :: !acs) ;
      List.rev !acs
    in
    Core.printf
      !"pre %{sexp:Account.t list}\n%!"
      (accounts (Ledger.iteri ledger)) ;
    Ledger.apply_transaction
      ~constraint_constants:
        (Lazy.force Precomputed_values.compiled).constraint_constants
      ~txn_state_view ledger snapp_command
    |> Or_error.ok_exn |> ignore ;
    let ledger_post =
      Ledger_hash.to_base58_check (Ledger.merkle_root ledger)
    in
    let sparse_ledger_post =
      Sparse_ledger.apply_transaction_exn ~constraint_constants ~txn_state_view
        sparse_ledger snapp_command
    in
    Core.printf "(%s, %s) -> (%s, %s)\n%!" ledger_pre
      (Sparse_ledger.merkle_root sparse_ledger |> Ledger_hash.to_base58_check)
      ledger_post
      ( Sparse_ledger.merkle_root sparse_ledger_post
      |> Ledger_hash.to_base58_check ) ;
    let open Async in
    let lpost =
      sprintf !"%{sexp:Account.t list}\n%!" (accounts (Ledger.iteri ledger))
    in
    let spost =
      sprintf
        !"%{sexp:Account.t list}\n%!"
        (accounts (Sparse_ledger.iteri sparse_ledger_post))
    in
    let%bind () = Writer.save "lpost" ~contents:lpost in
    let%bind () = Writer.save "spost" ~contents:spost in
    let%bind proc =
      Process.create_exn ~prog:"bash" ~args:["-c"; "colordiff lpost spost"] ()
    in
    let%bind () =
      Reader.transfer (Process.stdout proc)
        (Writer.pipe (Lazy.force Writer.stdout))
    in
    return ()
  in
  (*   same public key occurs twice in ledger *)
  let open Async.Command in
  let open Async.Command.Let_syntax in
  async ~summary:"test" (return main)

let verify =
  let open Command in
  let open Command.Let_syntax in
  basic ~summary:"Verify a proof"
    (let%map cache = cache_flag
     and public_input =
       Spec.choose_one ~if_nothing_chosen:Input.Public_input.Value.if_not_given
         [ Input.Public_input.Value.args
         ; Spec.flag "--public-input-sexp"
             ~doc:
               "s-expression Enter the public input in the form of an \
                s-expression"
             (Flag.optional
                (Arg_type.Export.sexp_conv Input.Public_input.Value.t_of_sexp))
         ; Spec.flag "--public-input-json"
             ~doc:"json Enter the public input in the json format"
             (Flag.optional
                (Arg_type.create (fun str ->
                     Yojson.Safe.from_string str
                     |> Input.Public_input.Value.of_yojson
                     |> Result.map_error ~f:(fun msg ->
                            Error.createf
                              "Could read the public input from the given \
                               JSON: %s"
                              msg )
                     |> Or_error.ok_exn ))) ]
     and proof =
       Spec.flag "--proof" ~doc:"PROOF The proof to verify"
         (Flag.required Arg_type.Export.string)
     in
     fun () ->
       let _, _, (module Proof), _ = compile ?cache () in
       let proof =
         Base64.decode_exn ~alphabet:Base64.uri_safe_alphabet proof
         |> Binable.of_string (module Side_loaded.Proof.Stable.Latest)
       in
       Core.printf
         !"demo statements %{sexp: Input.Public_input.Value.t list}\n%!"
         [public_input] ;
       Format.printf "Proof verified? %b@."
         (Proof.verify [(public_input, proof)]))

let () =
  run_commands ~additional_commands:[("verify", verify); ("test", test)] ()
