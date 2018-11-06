open Core_kernel
open Lite_base
open Js_of_ocaml
open Virtual_dom.Vdom
module V = Verifier

module Pos = struct
  type t = {x: float; y: float}
end

let float_to_string value = Js.to_string (Js.number_of_float value)##toString

module Svg = struct
  open Virtual_dom.Vdom

  let silver = "#8492A6"

  let main ?class_ ~width ~height cs =
    Node.svg "svg"
      ( [ Attr.create_float "width" width
        ; Attr.create_float "height" height
        ; Attr.create "xmlns" "http://www.w3.org/2000/svg" ]
      @ Option.to_list (Option.map class_ ~f:Attr.class_) )
      cs

  let path points line_color =
    let points =
      String.concat ~sep:" "
        (List.map points ~f:(fun {Pos.x; y} ->
             sprintf "%s,%s" (float_to_string x) (float_to_string y) ))
    in
    Node.svg "polyline"
      [ Attr.create "points" points
      ; Attr.create "style"
          (sprintf "fill:none;stroke:%s;stroke-width:1" line_color) ]
      []

  (* Make little merkle tree for mobile *)

  let circle ~radius ~color ~(center : Pos.t) =
    Node.svg "circle"
      [ Attr.create "r" (float_to_string radius)
      ; Attr.create "cx" (float_to_string center.x)
      ; Attr.create "cy" (float_to_string center.y)
      ; Attr.create "style" (sprintf "fill:%s" color) ]
      []

  let rect ?radius ~color ~width ~height ~(center : Pos.t) =
    let corner_x = center.x -. (width /. 2.) in
    let corner_y = center.y -. (height /. 2.) in
    let rad_attrs =
      Option.value_map radius ~default:[] ~f:(fun r ->
          [Attr.create_float "rx" r; Attr.create_float "ry" r] )
    in
    Node.svg "rect"
      ( [ Attr.create_float "x" corner_x
        ; Attr.create_float "y" corner_y
        ; Attr.create "style" (sprintf "fill:%s" color)
        ; Attr.create_float "width" width
        ; Attr.create_float "height" height ]
      @ rad_attrs )
      []

  let triangle ?radius ~color ~width ~height ~(center : Pos.t) =
    let p0x, p0y = (center.x -. (width /. 2.0), center.y +. (height /. 2.0)) in
    let p1x, p1y = (center.x +. (width /. 2.0), center.y +. (height /. 2.0)) in
    let p2x, p2y = (center.x, center.y -. (height /. 2.0)) in
    let rad_attrs =
      Option.value_map radius ~default:[] ~f:(fun r ->
          [Attr.create_float "rx" r; Attr.create_float "ry" r] )
    in
    Node.svg "polygon"
      ( [ Attr.create "points"
            (sprintf "%f,%f %f,%f %f,%f" p0x p0y p1x p1y p2x p2y)
        ; Attr.create "style" (sprintf "stroke:%s;fill:rgba(0,0,0,0)" color) ]
      @ rad_attrs )
      []
end

let rest_server_port = 8080

let url s = sprintf "http://localhost:%d/%s" rest_server_port s

let get_account _pk on_sucess on_error =
  let url = sprintf !"%s/chain" Web_response.s3_link in
  (* IF serialization does not work, please try the following code:
  
  let url = sprintf !"%s/sample_chain" s3_link in

     Use "%s/chain" in production
   *)
  Web_response.get url
    (fun s ->
      let chain = Binable.of_string (module Lite_chain) (B64.decode s) in
      on_sucess chain )
    on_error

let to_base64 m x = B64.encode (Binable.to_string m x)

module Tooltip_stage = struct
  type t = None | Proof | Blockchain_state | Account_state [@@deriving eq]
end

let start_time = Time.now ()

module State = struct
  type t =
    { verification:
        [`Pending of int | `Complete of Verifier.Response.result Or_error.t]
    ; chain: Lite_chain.t
    ; tooltip_stage: Tooltip_stage.t }

  let init =
    { verification= `Pending 0
    ; chain= Lite_params.genesis_chain
    ; tooltip_stage= None }

  let chain_length chain =
    chain.Lite_chain.protocol_state.consensus_state.length

  let should_update state (new_chain : Lite_chain.t) =
    Length.compare (chain_length new_chain) (chain_length state.chain) > 0
end

let color_of_hash (h : Pedersen.Digest.t) : string =
  let int_to_hex_char n =
    assert (0 <= n) ;
    assert (n < 16) ;
    if n < 10 then Char.of_int_exn (Char.to_int '0' + n)
    else Char.of_int_exn (Char.to_int 'A' + (n - 10))
  in
  let module N = Lite_base.Crypto_params.Tock.N in
  let n = Lite_base.Crypto_params.Tock.Fq.to_bigint h in
  let byte i =
    let bit ~start j =
      if N.test_bit n (start + (8 * i) + j) then 1 lsl j else 0
    in
    let char k =
      let c = bit ~start:(4 * k) in
      int_to_hex_char (c 0 lor c 1 lor c 2 lor c 3)
    in
    String.init 2 ~f:char
  in
  sprintf "#%s%s%s" (byte 0) (byte 1) (byte 2)

let map_adjacent_pairs xs ~f =
  let rec go acc = function
    | [_] | [] -> List.rev acc
    | x1 :: (x2 :: _ as xs) -> go (f x1 x2 :: acc) xs
  in
  go [] xs

let y_offset =
  let rec go acc pt n =
    if n = 0 then acc else go (pt +. acc) (pt /. 2.) (n - 1)
  in
  go 0. 0.5

let num_layers_to_show_desktop = 10

let num_layers_to_show_mobile = 4

let drop_top_of_tree ~desired_layers =
  let rec layers = function
    | Sparse_ledger_lib.Sparse_ledger.Node (_, l, r) ->
        1 + max (layers l) (layers r)
    | Account _ -> 1
    | Hash _ -> 1
  in
  let rec drop n t =
    if n = 0 then t
    else
      match t with
      | Sparse_ledger_lib.Sparse_ledger.Account _ | Hash _ ->
          failwith "Cannot drop from Account or Hash"
      | Node (_, Hash _, t') | Node (_, t', Hash _) -> drop (n - 1) t'
      | Node (_, Account _, Node _) | Node (_, Node _, Account _) ->
          failwith "Accounts should only be at leaves"
      | Node (_, Account _, Account _) ->
          failwith "Only one account per tree supported"
      | Node (_, Node _, Node _) ->
          failwith "Only single account trees supported"
  in
  fun t ->
    let n = layers t in
    if n <= desired_layers then t else drop (n - desired_layers) t

let style kvs =
  List.map ~f:(fun (k, v) -> sprintf "%s:%s" k v) kvs |> String.concat ~sep:";"

module Style = struct
  type t = string list

  let ( + ) = List.append

  let of_class s = [s]

  let empty = []

  let render t = Attr.(class_ (String.concat ~sep:" " t))

  let just = Fn.compose render of_class
end

module Visibility = struct
  let no_mobile = Style.of_class "dn db-ns"

  let only_large = Style.of_class "dn db-l"

  let only_mobile = Style.of_class "db dn-ns"
end

module Mobile_switch = struct
  let create ~not_small ~small =
    let open Node in
    div []
      [ div [Style.render Visibility.no_mobile] [not_small]
      ; div [Style.render Visibility.only_mobile] [small] ]
end

let g_update_state_and_vdom = ref (fun _ -> ())

let js_is_mobile_small () : bool =
  not (Js.Unsafe.js_expr "window.matchMedia(\"(min-width: 30em)\").matches")

module Html = struct
  open Virtual_dom.Vdom

  let grouping_style =
    Style.of_class "br3 bg-darksnow shadow-subtle ph2 pv2 relative"

  let div = Node.div

  let extend_class c co =
    c ^ Option.value_map ~default:"" co ~f:(fun s -> " " ^ s)

  module Tooltip = struct
    type text_part = [`Text of string | `New_line | `Link of string * string]

    type t =
      { active: bool
      ; text: text_part list
      ; alt_text: text_part list option
      ; arity: [`Left | `Right] }

    let create ~active ~text ?alt_text ~arity () =
      {text; alt_text; active; arity}

    let body ?(extra_style = Style.empty) text_node =
      div
        [ Style.(
            render
              ( of_class
                  "mw5 b-sky shadow-subtle br3 bg-darksnow ph3 pv3 roboto \
                   lh-copy bluesilver"
              + extra_style )) ]
        [ div
            [Style.(render (of_class "flex items-center" + extra_style))]
            [text_node] ]

    let join_text text =
      div []
        (List.join
           (List.map text ~f:(fun text ->
                match text with
                | `Text text -> [Node.text text]
                | `New_line -> [Node.create "br" [] []; Node.create "br" [] []]
                | `Link (text, link) ->
                    [ Node.a
                        [ Attr.href link
                        ; Style.(render (of_class "silver"))
                        ; Attr.create "target" "_blank" ]
                        [Node.text text] ] )))

    let render_overlay {active; text; arity= _; alt_text} =
      let text = Option.value alt_text ~default:text in
      let text = join_text text in
      let body = body ~extra_style:(Style.of_class "h-100") text in
      div
        [Style.render (if active then Style.empty else Style.of_class "dn")]
        [ div
            [ Style.(
                render
                  ( of_class "absolute left-0 top-0 o-90 h-100 w-100"
                  + Visibility.only_mobile )) ]
            [body] ]

    let render_wide {active; text; arity; alt_text= _} =
      let body = body (join_text text) in
      let chevron = match arity with `Left -> "›" | `Right -> "‹" in
      let chevron_dom =
        div [Style.just "silver ml3 mr3 f1 sky"] [Node.text chevron]
      in
      div
        [Style.render Visibility.no_mobile]
        [ div
            [ Style.(
                render
                  ( of_class "flex items-center animate-opacity"
                  + if active then Style.empty else of_class "o-30" )) ]
            ( match arity with
            | `Left -> [body; chevron_dom]
            | `Right -> [chevron_dom; body] ) ]
  end

  module Record = struct
    module Entry = struct
      type t =
        { label: string
        ; value: string
        ; verification:
            [`Pending of int | `Complete of Verifier.Response.result Or_error.t]
        ; important: bool
        ; extra_style: Style.t }

      let render
          {label= label_text; value; verification; important; extra_style} =
        let open Node in
        div
          [ Style.(
              render
                ( of_class "br3 shadow-subtle"
                + extra_style
                +
                match (important, verification) with
                | true, `Complete (Ok _) -> of_class "grass-gradient b-grass"
                | true, `Pending _ | false, _ ->
                    of_class "silver-gradient br3 b-silver"
                | true, `Complete (Error _) ->
                    of_class "bg-brightred br3 b-silver" )) ]
          [ div
              [Style.just "br3 pv2 br--top"]
              [ div
                  [Style.just "flex items-center"]
                  [ div
                      [ Style.(
                          render
                            ( of_class "dib ml3 mr2 ph1 br-100 w01 h01"
                            +
                            match verification with
                            | `Complete (Ok _) ->
                                of_class "shadow-small2 bg-grass"
                            | `Pending _ ->
                                of_class "shadow-small1 bg-dullgrey"
                            | `Complete (Error _) ->
                                of_class "shadow-small1 bg-brightred" )) ]
                      []
                  ; span [Style.just "ph1 fw5 darksnow"] [text label_text] ] ]
          ; div
              [ Style.(
                  render
                    ( of_class "br3 br--bottom pv3 ph3 ocean wb bg-darksnow"
                    + if important then of_class "f8" else of_class "f7" )) ]
              [text value] ]

      let create verification ?(extra_style = Style.empty) ?width
          ?(important = false) label value =
        let _ = width in
        {label; value; verification; extra_style; important}
    end

    module Row = struct
      type t = Entry.t list

      let render (t : t) = div [Style.just "mb2"] (List.map ~f:Entry.render t)
    end

    type t = {style: Style.t; rows: Row.t list; heading: string option}

    let create ?(style = Style.empty) heading rows = {style; rows; heading}

    let render ?tooltip ?(grouping = `Separate) {style; rows; heading} width =
      let width =
        match width with
        | `Wide -> Style.of_class "mw5"
        | `Thin -> Style.of_class "mw5"
      in
      let grouping =
        match grouping with
        | `Thin_together -> Style.of_class "b-silver ph2 pv2 br3"
        | `Together -> grouping_style
        | `Separate -> Style.empty
      in
      let maybe_tooltip_overlay =
        match tooltip with
        | None -> []
        | Some (`Left tooltip) | Some (`Right tooltip) ->
            [Tooltip.render_overlay tooltip]
      in
      let record =
        div
          [Style.(render (style + width + grouping))]
          ( ( match heading with
            | None -> []
            | Some heading ->
                [ Node.div
                    [Style.just "record-title-padding fw5 silver roboto tc"]
                    [Node.text heading] ] )
          @ List.map rows ~f:Row.render
          @ maybe_tooltip_overlay )
      in
      match tooltip with
      | None -> record
      | Some tooltip ->
          let content =
            match tooltip with
            | `Left tooltip -> [Tooltip.render_wide tooltip; record]
            | `Right tooltip -> [record; Tooltip.render_wide tooltip]
          in
          div
            [ Style.just
                "flex items-center flex-column flex-row-ns justify-center mb3 \
                 relative" ]
            content
  end
end

let field_to_base64 =
  Fn.compose Fold_lib.Fold.bool_t_to_string
    Lite_base.Crypto_params.Tock.Fq.fold_bits
  |> Fn.compose B64.encode

let hash_colors = [|"#76cd87"; "#4782a0"; "#ac80a0"; "#89aae6"; "#3685b5"|]

let color_at_layer i = hash_colors.(i mod Array.length hash_colors)

let hoverable ?(extra_style = Style.empty) state node target =
  let update_tooltip _ =
    if not (js_is_mobile_small ()) then
      !g_update_state_and_vdom {state with State.tooltip_stage= target} ;
    Event.Ignore
  in
  let reset_tooltip _ =
    if not (js_is_mobile_small ()) then
      !g_update_state_and_vdom
        {state with State.tooltip_stage= Tooltip_stage.None} ;
    Event.Ignore
  in
  let mobile_update_toggle _ =
    ( if js_is_mobile_small () then
      let target' =
        match (state.State.tooltip_stage, target) with
        | Tooltip_stage.None, _ -> target
        | x, y when Tooltip_stage.equal x y -> Tooltip_stage.None
        | _ -> target
      in
      !g_update_state_and_vdom {state with State.tooltip_stage= target'} ) ;
    Event.Stop_propagation
  in
  let open Node in
  let open Attr in
  div
    [ Style.(render (of_class "mobile-jank-fix" + extra_style))
    ; on_mouseenter update_tooltip
    ; on_mouseleave reset_tooltip
    ; on_click mobile_update_toggle ]
    [node]

let merkle_tree num_layers_to_show =
  let module Spec = struct
    type t =
      | Node of {pos: Pos.t; color: string}
      | Account of {pos: Pos.t; account: Account.t}

    let pos = function Node {pos; _} -> pos | Account {pos; _} -> pos
  end in
  let layer_height = 20. in
  let image_width = 240. in
  let top_offset = 15. in
  let left_offset = 0. in
  let image_height = Int.to_float num_layers_to_show *. layer_height in
  let x_delta = 0.7 *. image_width /. Float.of_int num_layers_to_show in
  let x_pos, y_pos =
    let y_uncompressed ~layer =
      top_offset +. (Int.to_float layer *. layer_height)
    in
    let x_uncompressed =
      let delta = x_delta in
      fun ~layer ~index ->
        let rec go remaining_depth acc pt =
          if remaining_depth = 0 then acc
          else
            let b = pt mod 2 = 1 in
            let acc = if b then acc +. delta else acc -. delta in
            go (remaining_depth - 1) acc (pt / 2)
        in
        left_offset +. go layer (image_width /. 2.) index
    in
    (*
    let _x_compressed =
      fun ~layer ~index ->
        let nodes_in_layer = 1 lsl layer in
        assert (index < nodes_in_layer);
        let cell_width =
          width /. Float.of_int nodes_in_layer
        in
        let left = Float.of_int index *. cell_width in
        left +. cell_width /. 2.
    in
    let _y_compressed =
      fun ~layer ->
        top_offset +. (y_offset layer *. image_height)
    in
*)
    (x_uncompressed, y_uncompressed)
  in
  fun state (tree0 : ('hash, 'account) Sparse_ledger_lib.Sparse_ledger.tree)
      ~extra_style ->
    let verification = state.State.verification in
    let create_entry = Html.Record.Entry.create verification in
    let tree0 = drop_top_of_tree ~desired_layers:num_layers_to_show tree0 in
    let specs =
      let rec go acc layer index
          (t : ('h, 'a) Sparse_ledger_lib.Sparse_ledger.tree) =
        let pos : Pos.t = {x= x_pos ~layer ~index; y= y_pos ~layer} in
        let hash_spec = Spec.Node {pos; color= color_at_layer layer} in
        let finish x = List.rev (x :: acc) in
        match t with
        | Account account -> finish (Spec.Account {account; pos})
        | Hash _h -> finish hash_spec
        | Node (_h, Hash _, r) ->
            go (hash_spec :: acc) (layer + 1) ((2 * index) + 1) r
        | Node (_h, l, Hash _) ->
            go (hash_spec :: acc) (layer + 1) ((2 * index) + 0) l
        | Node (_, Account _, Node _) | Node (_, Node _, Account _) ->
            failwith "Accounts should only be at leaves"
        | Node (_, Account _, Account _) ->
            failwith "Only one account per tree supported"
        | Node (_, Node _, Node _) ->
            failwith "Only single account trees supported"
      in
      go [] 0 0 tree0
    in
    let xs =
      List.map specs ~f:(fun spec ->
          let pos = Spec.pos spec in
          pos.x )
    in
    let avg_x =
      List.reduce_exn xs ~f:(fun a b -> a +. b)
      /. Float.of_int (List.length xs)
    in
    let specs =
      List.map specs ~f:(fun spec ->
          match spec with
          | Spec.Account spec ->
              let pos = {spec.pos with x= spec.pos.x +. (avg_x *. 0.5)} in
              Spec.Account {pos; account= spec.account}
          | Spec.Node spec ->
              let pos = {spec.pos with x= spec.pos.x +. (avg_x *. 0.5)} in
              Spec.Node {pos; color= spec.color} )
    in
    let rendered =
      let account =
        match List.last_exn specs with
        | Spec.Node _ -> None
        | Spec.Account
            {pos= _; account= {public_key; balance; nonce; receipt_chain_hash}}
          ->
            let record =
              let open Html.Record in
              create None
                [ [ create_entry ~extra_style:(Style.of_class "mb2") "balance"
                      ~width:"50%"
                      (Account.Balance.to_string balance)
                  ; create_entry ~extra_style:(Style.of_class "mb2")
                      "public_key" ~width:"50%"
                      (to_base64 (module Public_key.Compressed) public_key)
                  ; create_entry ~extra_style:(Style.of_class "mb2") "nonce"
                      ~width:"50%"
                      (Account.Nonce.to_string nonce)
                  ; create_entry "receipt_chain" ~width:"50%"
                      (field_to_base64 receipt_chain_hash) ] ]
            in
            Some (Html.Record.render ~grouping:`Thin_together record `Wide)
      in
      let drop_last x = List.rev (List.drop (List.rev x) 1) in
      let edges =
        let posns = List.map specs ~f:Spec.pos in
        let posns =
          if List.length posns > 1 then
            let src = List.nth_exn posns (List.length posns - 2) in
            let dest = List.nth_exn posns (List.length posns - 1) in
            let last =
              {Pos.x= image_width /. 3.0; y= dest.y +. (dest.y -. src.y)}
            in
            (*let last = { Pos.x = dest.x +. (dest.x -. src.x); y = dest.y +. (dest.y -. src.y) } in*)
            drop_last posns @ [last]
          else posns
        in
        Svg.path posns "#8492A6"
      in
      let sibling_edge_positions =
        let srcs = drop_last specs in
        let dests = List.drop specs 1 in
        let edges =
          List.map2_exn srcs dests ~f:(fun src dest ->
              let pos_src = Spec.pos src in
              let pos_dest = Spec.pos dest in
              let right = pos_src.x > pos_dest.x in
              let pos_dest =
                if right then {pos_dest with x= pos_dest.x +. (x_delta *. 2.0)}
                else {pos_dest with x= pos_dest.x -. (x_delta *. 2.0)}
              in
              let pos_dest =
                { Pos.x= pos_src.x +. ((pos_dest.x -. pos_src.x) /. 1.0)
                ; y= pos_src.y +. ((pos_dest.y -. pos_src.y) /. 1.0) }
              in
              (pos_src, pos_dest, right) )
        in
        edges
      in
      let sibling_edges =
        List.map sibling_edge_positions ~f:(fun (src, dest, _) ->
            let dest =
              if src.x < dest.x then {Pos.x= dest.x -. 3.0; y= dest.y -. 6.0}
              else {Pos.x= dest.x +. 3.0; y= dest.y -. 6.0}
            in
            Svg.path [src; dest] "#bcbcbc" )
      in
      let colors =
        List.filter_map specs ~f:(fun spec ->
            match spec with
            | Spec.Node {pos= _; color} -> Some color
            | Spec.Account _ -> None )
      in
      let colors =
        if List.length colors <> List.length sibling_edge_positions then
          drop_last colors
        else colors
      in
      let sibling_nodes =
        List.map2_exn sibling_edge_positions colors
          ~f:(fun (_, dest, right) _ ->
            let color = "#bcbcbc" in
            let size = 12.0 in
            let center =
              if right then {Pos.x= dest.Pos.x -. 3.0; y= dest.y}
              else {Pos.x= dest.Pos.x +. 3.0; y= dest.y}
            in
            Svg.triangle ~radius:0.0 ~center ~width:size ~height:size ~color )
      in
      let nodes =
        List.filter_mapi specs ~f:(fun i spec ->
            let radius = if i = 0 then 12.0 else 7.0 in
            match spec with
            | Spec.Node {pos; color} ->
                Some (Svg.circle ~radius ~color ~center:pos)
            | Spec.Account _ -> None )
      in
      let tooltip =
        Html.Tooltip.create
          ~active:Tooltip_stage.(equal Account_state state.State.tooltip_stage)
          ~arity:`Right ~text:Copy.account_tooltip ()
      in
      hoverable state
        (Node.div
           [ Style.just
               "flex items-center flex-column flex-row-ns justify-center" ]
           [ Node.div
               [Style.(render (of_class "mw5 relative" + Html.grouping_style))]
               ( Node.div
                   [Style.just "record-title-padding fw5 silver roboto tc"]
                   [Node.text "Merkle-path and account"]
                 :: Svg.main
                      ~width:(image_width +. left_offset)
                      ~height:(image_height +. top_offset)
                      ((edges :: sibling_edges) @ nodes @ sibling_nodes)
                 :: Option.to_list account
               @ [Html.Tooltip.render_overlay tooltip] )
           ; Html.Tooltip.render_wide tooltip ])
        ~extra_style Tooltip_stage.Account_state
    in
    rendered

module Bottom_ctas = struct
  let a_style =
    Style.of_class
      "bg-ocean f4 darksnow no-underline ph3 br3 shadow-small2 dib \
       hover-bg-darkocean"

  let twitter =
    let open Node in
    let href =
      Attr.href
        "https://twitter.com/intent/retweet?tweet_id=1046805779976617984"
    in
    let itag = Node.create "i" in
    let bird =
      itag
        [ Style.just
            "pl1 ml-1 ml-2-ns fab f1 f2-m f1-l fa-twitter mr3 mr2-m mr3-l" ]
        []
    in
    a
      [href; Style.(render (a_style + of_class "mt3 mt0-ns pv2"))]
      [ div
          [Style.just "flex items-center"]
          [span [] [bird]; span [] [text "Share"]] ]

  let testnet_status =
    let open Node in
    let href = Attr.href "https://status.codaprotocol.com" in
    a
      [ href
      ; Style.(render (a_style + of_class "pv3"))
      ; Attr.create "target" "_blank" ]
      [text "Testnet Status"]

  let create () =
    let open Node in
    div
      [Style.just "mt4 tc tl-ns flex-ns justify-around-ns items-center-ns"]
      [testnet_status; twitter]
end

let state_html state =
  let { State.verification
      ; tooltip_stage= _
      ; chain=
          { protocol_state=
              {previous_state_hash; blockchain_state; consensus_state}
          ; ledger
          ; proof } } =
    state
  in
  let {Blockchain_state.ledger_builder_hash; ledger_hash; timestamp} =
    blockchain_state
  in
  let {Consensus_state.length; _} = consensus_state in
  let div = Node.div in
  let class_ = Attr.class_ in
  let timestamp =
    let time =
      Time.of_span_since_epoch (Time.Span.of_ms (Int64.to_float timestamp))
    in
    Time.to_string_iso8601_basic time ~zone:Time.Zone.utc
  in
  let create_entry = Html.Record.Entry.create verification in
  let proof_style =
    Style.of_class
    @@
    match verification with
    | `Complete (Ok _) -> "grass-gradient b-grass"
    | `Complete (Error _) -> "proof"
    | `Pending _ -> "proof verifying shake shake-constant"
  in
  let proof_style = Style.(proof_style + of_class "wb") in
  let state_hash =
    match verification with
    | `Complete (Ok {state_hash}) -> field_to_base64 state_hash
    | `Complete (Error _e) -> "Could not verify SNARK"
    | `Pending _ -> "Verification pending..."
  in
  let state_record =
    let open Html.Record in
    create (Some "Protocol state")
      [ [create_entry "state_hash" state_hash]
      ; [ create_entry "previous_state_hash"
            (field_to_base64 previous_state_hash) ]
      ; [create_entry "length" (Length.to_string length)]
      ; [create_entry "timestamp" timestamp]
      ; [create_entry "locked_ledger_hash" (field_to_base64 ledger_hash)]
      ; [ create_entry "staged_ledger_hash"
            (field_to_base64 ledger_builder_hash.ledger_hash) ] ]
  in
  let hoverable = hoverable state in
  let _ = ledger in
  let snark_tooltip =
    Html.Tooltip.create
      ~active:Tooltip_stage.(equal Proof state.State.tooltip_stage)
      ~arity:`Left ~text:Copy.proof_tooltip ~alt_text:Copy.proof_tooltip_alt ()
  in
  let state_tooltip =
    Html.Tooltip.create
      ~active:Tooltip_stage.(equal Blockchain_state state.State.tooltip_stage)
      ~arity:`Left ~text:Copy.state_tooltip ()
  in
  let age = Time.diff (Time.now ()) (Time.of_string timestamp) in
  let down_maintenance =
    if Time.Span.(age > Time.Span.of_sec 180.0) then (
      printf "most recent protocol state age: %s\n" (Time.Span.to_string age) ;
      [ (let heading_style =
           let open Style in
           of_class
             "fw4 darksnow tc mt0 mb4 f4 bg-lemoncurry br3 shadow-subtle pa3 \
              dib lh-copy"
         in
         div
           [Style.(render (of_class "flex justify-center"))]
           [ div
               [Style.render heading_style]
               [ div
                   [ Style.(
                       render
                         (of_class
                            "dib mr3 ml2 ph1 br-100 w01 bg-dullgrey h01 pr3"))
                   ]
                   []
               ; Node.text "System is currently down, check "
               ; Node.a
                   [ Attr.href "http://status.codaprotocol.com"
                   ; Attr.create "target" "_blank"
                   ; Style.(render (of_class "darksnow")) ]
                   [Node.text "status page"]
               ; Node.text " for updates" ] ]) ] )
    else []
  in
  let state_explorer =
    div
      [class_ "state-explorer flex-ll items-center"]
      [ div
          [class_ "state-with-proof mw7 mr4-ll"]
          [ hoverable
              (Html.Record.render ~grouping:`Together
                 ~tooltip:(`Left snark_tooltip)
                 (Html.Record.create (Some "Succinct blockchain")
                    [ [ create_entry ~important:true ~extra_style:proof_style
                          "zk-SNARK"
                          (to_base64 (module Proof) proof) ] ])
                 `Thin)
              Tooltip_stage.Proof
          ; hoverable
              (Html.Record.render ~grouping:`Together
                 ~tooltip:(`Left state_tooltip) state_record `Wide)
              Tooltip_stage.Blockchain_state ]
      ; hoverable
          (let tree = Sparse_ledger_lib.Sparse_ledger.tree ledger in
           let extra_style = Style.of_class "mw7" in
           Mobile_switch.create
             ~not_small:
               (merkle_tree num_layers_to_show_desktop state tree ~extra_style)
             ~small:
               (merkle_tree num_layers_to_show_mobile state tree ~extra_style))
          Tooltip_stage.Account_state ]
  in
  let explanation =
    let heading_style =
      Style.(of_class "silver tc mt0 mb4 f5 mw6 center fw3 lh-copy")
    in
    let br = Node.create "br" in
    Node.h2
      [Style.render heading_style]
      [ Node.text
          "The properties below constitute the full, live Coda protocol state \
           and are being fully verified in your browser."
      ; br [] []
      ; br [] []
      ; Mobile_switch.create
          ~not_small:
            (Node.text "Hover over any component below to learn more.")
          ~small:(Node.text "Tap any component below to learn more.") ]
  in
  let contents =
    (explanation :: down_maintenance) @ [state_explorer; Bottom_ctas.create ()]
  in
  let page_time = Time.diff (Time.now ()) start_time in
  if
    state.chain = Lite_params.genesis_chain
    && Time.Span.(page_time < Time.Span.of_sec 4.0)
  then div [Style.(render (of_class "animate-opacity o-0"))] contents
  else div [Style.(render (of_class "animate-opacity o-100"))] contents

let main ~render ~get_data =
  let state = ref State.init in
  let vdom = ref (render !state) in
  let elt = (Node.to_dom !vdom :> Dom.element Js.t) in
  let node = Dom_html.getElementById_exn "block-explorer" in
  Dom.appendChild node elt ;
  let update_state_and_vdom new_state =
    state := new_state ;
    let new_vdom = render new_state in
    let patch = Node.Patch.create ~previous:!vdom ~current:new_vdom in
    Node.Patch.apply patch elt |> ignore ;
    vdom := new_vdom
  in
  g_update_state_and_vdom := update_state_and_vdom ;
  let verifier = Verifier.create () in
  Verifier.set_on_message verifier ~f:(fun resp ->
      match !state.verification with
      | `Pending id when id = Verifier.Response.id resp ->
          update_state_and_vdom
            { !state with
              verification= `Complete (Verifier.Response.result resp) }
      | _ -> () ) ;
  let latest_completed = ref (-1) in
  let count = ref 0 in
  let loop () =
    let id = !count in
    incr count ;
    get_data ~on_result:(fun chain ->
        if id > !latest_completed then (
          latest_completed := id ;
          if State.should_update !state chain then (
            let new_state = {!state with verification= `Pending id; chain} in
            update_state_and_vdom new_state ;
            Verifier.send_verify_message verifier (chain, id) ) ) )
  in
  loop () ;
  ignore
    (Dom_html.window##setInterval (Js.wrap_callback (fun _ -> loop ())) 5_000.) ;
  Dom_html.window##setTimeout
    (Js.wrap_callback (fun _ -> update_state_and_vdom !state))
    5_000.

let _ =
  main
    ~get_data:(fun ~on_result ->
      get_account () on_result (fun e ->
          Firebug.console##log (Error.to_string_hum e) ) )
    ~render:state_html
