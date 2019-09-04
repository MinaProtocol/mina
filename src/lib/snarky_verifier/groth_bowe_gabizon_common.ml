open Core

module type Inputs_intf = sig
  module Impl : Snarky.Snark_intf.S

  module Fqe : Inputs.Fqe_intf with module Impl := Impl

  include
    Inputs.S
    with module Impl := Impl
     and module Fqe := Fqe
     and type Fqk.t = Fqe.t * Fqe.t
end

module Make_verification_key (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax

  type ('g1, 'g2, 'fqk) t_ =
    {query_base: 'g1; query: 'g1 list; delta: 'g2; alpha_beta: 'fqk}
  [@@deriving fields]

  let to_hlist {query_base; query; delta; alpha_beta} :
      (unit, _) Snarky.H_list.t =
    Snarky.H_list.[query_base; query; delta; alpha_beta]

  let of_hlist :
         (unit, 'g1 -> 'g1 list -> 'g2 -> 'fqk -> unit) Snarky.H_list.t
      -> ('g1, 'g2, 'fqk) t_ = function
    | [query_base; query; delta; alpha_beta] ->
        {query_base; query; delta; alpha_beta}

  let typ' ~input_size ~g1 ~g2 ~fqk =
    Snarky.Typ.of_hlistable
      Data_spec.[g1; Snarky.Typ.list ~length:input_size g1; g2; fqk]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let typ ~input_size = typ' ~input_size ~g1:G1.typ ~g2:G2.typ ~fqk:Fqk.typ

  include Summary.Make (Inputs)

  let summary_length_in_bits ~twist_extension_degree ~input_size =
    summary_length_in_bits ~twist_extension_degree ~g1_count:(input_size + 1)
      ~g2_count:1 ~gt_count:1

  let summary_input {query_base; query; delta; alpha_beta} =
    {Summary.Input.g1s= query_base :: query; g2s= [delta]; gts= [alpha_beta]}

  type ('a, 'b, 'c) vk = ('a, 'b, 'c) t_

  let if_pair if_ b ~then_:(tx, ty) ~else_:(ex, ey) =
    let%map x = if_ b ~then_:tx ~else_:ex and y = if_ b ~then_:ty ~else_:ey in
    (x, y)

  let if_g1 b ~then_ ~else_ = if_pair Field.Checked.if_ b ~then_ ~else_

  let if_g2 b ~then_ ~else_ = if_pair Fqe.if_ b ~then_ ~else_

  let if_list if_ b ~then_ ~else_ =
    Checked.List.map (List.zip_exn then_ else_) ~f:(fun (t, e) ->
        if_ b ~then_:t ~else_:e )

  let if_ b ~then_ ~else_ =
    let c if_ p = if_ b ~then_:(p then_) ~else_:(p else_) in
    let%map query_base = c if_g1 query_base
    and query = c (if_list if_g1) query
    and delta = c if_g2 delta
    and alpha_beta = c Fqk.if_ alpha_beta in
    {query_base; query; delta; alpha_beta}

  module Compressed = struct
    type nonrec ('field, 'fqe) t_ =
      { x_coordinates: ('field, 'fqe, 'fqe) t_
      ; y_bits: 'field
            (* We can also stuff the tick-to-tock extra bits in here *) }

    let typ' ~input_size ~fq ~fqe ~y_bits =
      let x_coordinates = typ' ~input_size ~g1:fq ~g2:fqe ~fqk:fqe in
      let open Snarky.H_list in
      let to_hlist {x_coordinates; y_bits} = [x_coordinates; y_bits] in
      let of_hlist : (unit, _) t -> _ =
       fun [x_coordinates; y_bits] -> {x_coordinates; y_bits}
      in
      Snarky.Typ.of_hlistable
        Data_spec.[x_coordinates; y_bits]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist

    (* TODO:  How can this be derived automatically from the typ' value? *)
    let to_list' ~fq ~fqe ~y_bits:f_y_bits
        {x_coordinates= {delta; query_base; query; alpha_beta}; y_bits} =
      List.concat
        [ List.concat
            [fq query_base :: List.map ~f:fq query; fqe delta; fqe alpha_beta]
        ; [f_y_bits y_bits] ]

    let to_list t = to_list' ~fq:Fn.id ~fqe:Fqe.to_list ~y_bits:Fn.id t

    let typ ~input_size =
      typ' ~input_size ~fq:Field.typ ~fqe:Fqe.typ ~y_bits:Field.typ

    module Y_bits = struct
      let of_list = function
        | delta :: alpha_beta :: query_base :: query ->
            {delta; alpha_beta; query_base; query}
        | _ ->
            failwith "Y_bits.of_list: Input not long enough"

      let to_list {delta; alpha_beta; query_base; query} =
        delta :: alpha_beta :: query_base :: query

      let length ~input_size =
        let add n acc _ = acc + n in
        (* This is just to make sure we don't miss any fields *)
        Fields_of_t_.fold ~init:0 ~query_base:(add 1) ~query:(add input_size)
          ~delta:(add 1) ~alpha_beta:(add 1)
    end

    let unpack_bits y_bits ~input_size =
      Field.Checked.choose_preimage_var
        ~length:(Y_bits.length ~input_size)
        y_bits
      >>| Y_bits.of_list

    (* Return [(a, b)] where [b : F] has the appropriate parity add [a*a + b*b = 1] *)
    let decompress_unitary_fqk ((a : Fqe.t), is_odd) =
      let%bind (b : Fqe.t) =
        exists Fqe.typ
          ~compute:
            As_prover.(
              Let_syntax.(
                let%map a = read Fqe.typ a
                and is_odd = read Boolean.typ is_odd in
                let b = Fqe.Unchecked.(sqrt (square a - one)) in
                if is_odd <> Field.parity (Fqe.real_part b) then
                  Fqe.Unchecked.negate b
                else b))
      in
      let%map () =
        let%bind a2 = Fqe.square a in
        Fqe.(assert_square b (one - a2))
      and () =
        Field.Checked.parity (Fqe.real_part b)
        >>= Boolean.Assert.(( = ) is_odd)
      in
      (a, b)

    let decompress {x_coordinates; y_bits} =
      let%bind y_bits =
        unpack_bits y_bits ~input_size:(List.length x_coordinates.query)
      in
      let b k f g = k (f x_coordinates, g y_bits) in
      let g1_list f g =
        Checked.List.map ~f:G1.decompress
          (List.zip_exn (f x_coordinates) (g y_bits))
      in
      let%map query_base = b G1.decompress query_base query_base
      and query = g1_list query query
      and delta = b G2.decompress delta delta
      and alpha_beta = b decompress_unitary_fqk alpha_beta alpha_beta in
      {query_base; query; delta; alpha_beta}

    module Unchecked = struct
      let compress t =
        let ( -| ) = Fn.compose in
        let get field = Core.Field.get field t in
        let get_coords ~g1 ~g2 ~fqk =
          let coord proj to_affine_exn field =
            proj (to_affine_exn (get field))
          in
          Fields_of_t_.map
            ~query_base:(coord g1 G1.Unchecked.to_affine_exn)
            ~delta:(coord g2 G2.Unchecked.to_affine_exn)
            ~query:(fun f ->
              List.map ~f:(g1 -| G1.Unchecked.to_affine_exn) (get f) )
            ~alpha_beta:(coord fqk Fn.id)
        in
        { x_coordinates= get_coords ~g1:fst ~g2:fst ~fqk:fst
        ; y_bits=
            get_coords ~g1:(Field.parity -| snd)
              ~g2:(Field.parity -| Fqe.real_part -| snd)
              ~fqk:(Field.parity -| Fqe.real_part -| snd)
            |> Y_bits.to_list |> Field.project }
    end
  end

  module Precomputation = struct
    type t = {delta: G2_precomputation.t}

    let create (vk : (_, _, _) vk) =
      let%map delta = G2_precomputation.create vk.delta in
      {delta}

    let create_constant (vk : (_, _, _) vk) =
      {delta= G2_precomputation.create_constant vk.delta}

    let if_ b ~then_ ~else_ =
      let%map delta =
        G2_precomputation.if_ b ~then_:then_.delta ~else_:else_.delta
      in
      {delta}
  end
end
