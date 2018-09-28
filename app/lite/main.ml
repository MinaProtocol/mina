open Core_kernel
open Lite_base
open Js_of_ocaml
open Virtual_dom.Vdom
module V = Verifier

module Pos = struct
  type t = {x: float; y: float}
end

let float_to_string value = Js.to_string (Js.number_of_float value) ## toString

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

  let line_color = silver

  let path points =
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
      ; Attr.create "style" (sprintf "fill:%s" color)
      ] []

  let rect ?radius ~color ~width ~height ~(center: Pos.t) =
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

  let triangle ?radius ~color ~width ~height ~(center: Pos.t) =
    let p0x, p0y = (center.x -. width /. 2.0, center.y +. height /. 2.0) in
    let p1x, p1y = (center.x +. width /. 2.0, center.y +. height /. 2.0) in
    let p2x, p2y = (center.x, center.y -. height /. 2.0) in
    let rad_attrs =
      Option.value_map radius ~default:[] ~f:(fun r ->
          [Attr.create_float "rx" r; Attr.create_float "ry" r] )
    in
    Node.svg "polygon"
      ( [ Attr.create "points" (sprintf "%f,%f %f,%f %f,%f" p0x p0y p1x p1y p2x p2y)
        ; Attr.create "style" (sprintf "fill:%s" color) ]
      @ rad_attrs )
      []
end

let rest_server_port = 8080

let url s = sprintf "http://localhost:%d/%s" rest_server_port s

let get url on_success on_error =
  let req = XmlHttpRequest.create () in
  req ##. onerror :=
    Dom.handler (fun _e ->
        on_error (Error.of_string "get request failed") ;
        Js._false ) ;
  req ##. onload :=
    Dom.handler (fun _e ->
        ( match Js.Opt.to_option (File.CoerceTo.string req ##. response) with
        | None -> on_error (Error.of_string "get request failed")
        | Some s -> on_success (Js.to_string s) ) ;
        Js._false ) ;
  req ## _open (Js.string "GET") (Js.string url) Js._true ;
  req ## send Js.Opt.empty

let s3_link = "https://s3-us-west-2.amazonaws.com/o1labs-snarkette-data"

let get_account _pk on_sucess on_error =
  let url = sprintf !"%s/sample_chain" s3_link in
  (* IF serialization does not work, please try the following code:
  
  let url = sprintf !"%s/sample_chain" s3_link in

     Use "%s/chain" in production
   *)
  get url
    (fun s ->
      let s = String.slice s 0 (String.length s - 1) in
      let chain = Binable.of_string (module Lite_chain) (B64.decode s) in
      on_sucess chain )
    on_error

let to_base64 m x = B64.encode (Binable.to_string m x)

module App_stage = struct
  type t =
    | Intro
    | Problem
    | Coda
    | Mission
    | App
end

module Tooltip_stage = struct
  type t =
    | None
    | Proof
    | Blockchain_state
    | Account_state
  [@@deriving eq]
end

module Download_progress = struct
  type t = 
    | Progress of int
    | Done

end

module State = struct
  type t =
    { verification: [`Pending of int | `Complete of unit Or_error.t]
    ; chain: Lite_chain.t
    ; app_stage: App_stage.t
    ; tooltip_stage: Tooltip_stage.t
    ; download_progress: Download_progress.t
    }

  let init = {verification= `Complete (Ok ()); chain= Lite_params.genesis_chain; app_stage = Intro; tooltip_stage = None; download_progress = Done}

  let chain_length chain =
    chain.Lite_chain.protocol_state.consensus_state.length

  let should_update state (new_chain: Lite_chain.t) =
    Length.compare (chain_length new_chain) (chain_length state.chain) > 0
end

let color_of_hash (h: Pedersen.Digest.t) : string =
  let int_to_hex_char n =
    assert (0 <= n) ;
    assert (n < 16) ;
    if n < 10 then Char.of_int_exn (Char.to_int '0' + n)
    else Char.of_int_exn (Char.to_int 'A' + (n - 10))
  in
  let module N = Snarkette.Mnt6.N in
  let n = Snarkette.Mnt6.Fq.to_bigint h in
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

module Html = struct
  open Virtual_dom.Vdom

  let grouping_style =
     Style.of_class "br3 bg-darksnow shadow-subtle ph2 pv2"

  let div = Node.div

  let extend_class c co =
    c ^ Option.value_map ~default:"" co ~f:(fun s -> " " ^ s)

  module Tooltip = struct
    let create ~active ~text ~arity =
      let body =
        div [Style.just "mw5 b-sky shadow-subtle br3 bg-darksnow ph3 pv3 roboto lh-copy bluesilver"]
            [Node.text text]
      in
      let chevron =
        match arity with
        | `Left -> "›"
        | `Right -> "‹"
      in
      let chevron_dom =
        div [Style.just "silver ml3 mr3"] [Node.text chevron]
      in
      div [Style.(render (of_class "flex items-center" + if active then Style.empty else (of_class "o-10")))]
        (match arity with
        | `Left ->
          [ body
          ; chevron_dom ]
        | `Right ->
          [ chevron_dom
          ; body ])
  end

  module Record = struct
    module Entry = struct
      type t =
        { label: string
        ; value: string
        ; verification: [`Pending of int | `Complete of unit Or_error.t]
        ; important: bool
        ; extra_style: Style.t
        }

      let render {label=label_text; value; verification; important; extra_style} =
        let open Node in
        div [Style.(render
            (of_class "br3 silver-gradient b-silver shadow-subtle" + extra_style + 
              (match (important, verification) with
              | true, `Complete (Ok ()) -> (of_class "grass-gradient b-grass")
              | true, `Complete (Error _) | (true, `Pending _) | (false, _) -> (of_class "silver-gradient br3 b-silver"))
            )) ]
          [ div [Style.just "br3 pv1 br--top"]
            [div [Style.just "flex items-center"]
              [div
                [Style.(render (
                (of_class "dib ml3 mr2 ph1 br-100 w01 h01")
                  + (match verification with
                    | `Complete (Ok ()) -> (of_class "shadow-small2 bg-grass")
                    | `Complete (Error _) | `Pending _ -> (of_class "shadow-small1 bg-dullgrey"))))] []
              ; span [Style.just "ph1 fw5 darksnow"] [text label_text]
              ]
            ]
          ; div [Style.(render (of_class "br3 br--bottom pv3 ph3 ocean wb bg-darksnow" + if important then (of_class "f8") else (of_class "f7")))] [text value] ]

      let create verification ?(extra_style=Style.empty) ?width ?(important=false) label value =
        let _ = width in
        {label; value; verification; extra_style; important}
    end

    module Row = struct
      type t = Entry.t list

      let render (t: t) =
        div [Style.just "mb2"] (List.map ~f:Entry.render t)
    end

    type t = {style: Style.t; rows: Row.t list}

    let create ?(style=Style.empty) rows =
      {style; rows}

    let render ?tooltip ?(grouping=`Separate) {style; rows} width =
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
      let record =
          div
              [Style.(render (style + width + grouping))]
              (List.map rows ~f:Row.render)
      in
      match tooltip with
      | None -> record
      | Some tooltip ->
        let content =
          match tooltip with
          | `Left tooltip ->
              [tooltip; record]
          | `Right tooltip ->
              [record; tooltip]
        in
        div [Style.just "flex items-center mb3"]
          content
  end
end

let field_to_base64 =
  Fn.compose Fold_lib.Fold.bool_t_to_string Snarkette.Mnt6.Fq.fold_bits
  |> Fn.compose B64.encode

let hash_colors =
  [|
    "#76cd87"
  ; "#4782a0"
  ; "#ac80a0"
  ; "#89aae6"
  ; "#3685b5"
  |]

let color_at_layer i = hash_colors.(i mod (Array.length hash_colors))

let g_update_state_and_vdom = ref (fun _ -> ())

let hoverable state node target attrs =
  let update_tooltip  _ = 
    !g_update_state_and_vdom { state with State.tooltip_stage=target };
    Event.Ignore
  in
  let reset_tooltip _ =
    !g_update_state_and_vdom { state with State.tooltip_stage=Tooltip_stage.None };
    Event.Ignore
  in
  let open Node in
  let open Attr in
  div ([on_mouseenter update_tooltip; on_mouseleave reset_tooltip] @ attrs) [ node ]


let merkle_tree num_layers_to_show =
  let module Spec = struct
    type t =
      | Node of {pos: Pos.t; color: string}
      | Account of {pos: Pos.t; account: Account.t}

    let pos = function Node {pos; _} -> pos | Account {pos; _} -> pos
  end in
  let layer_height = 25. in
  let image_width = 240. in
  let top_offset = 15. in
  let left_offset = 0. in
  let image_height = Int.to_float num_layers_to_show *. layer_height in
  let x_delta = 0.5 *. image_width /. Float.of_int num_layers_to_show in
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
  fun state (tree0: ('hash, 'account) Sparse_ledger_lib.Sparse_ledger.tree) ->
    let verification = state.State.verification in
    let create_entry = Html.Record.Entry.create verification in
    let tree0 = drop_top_of_tree ~desired_layers:num_layers_to_show tree0 in
    let specs =
      let rec go acc layer index
          (t: ('h, 'a) Sparse_ledger_lib.Sparse_ledger.tree) =
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
    let rendered =
      let account =
        match List.last_exn specs with
        | Spec.Node _ -> None
        | Spec.Account
            { pos=_
            ; account= {public_key; balance; nonce; receipt_chain_hash} } ->
            let record =
              let open Html.Record in
              create
                [[ create_entry ~extra_style:(Style.of_class "mb2") "balance" ~width:"50%"
                      (Account.Balance.to_string balance)
                  ; create_entry ~extra_style:(Style.of_class "mb2") "public_key" ~width:"50%"
                      (to_base64 (module Public_key.Compressed) public_key)
                ; create_entry ~extra_style:(Style.of_class "mb2") "nonce" ~width:"50%"
                      (Account.Nonce.to_string nonce)
                  ; create_entry "receipt_chain" ~width:"50%"
                      (field_to_base64 receipt_chain_hash) ]]
            in
            Some (Html.Record.render ~grouping:`Thin_together record `Wide)
      in
      let drop_last x = List.rev (List.drop (List.rev x) 1) in
      let edges =
        let posns =
          List.map specs ~f:Spec.pos
        in
        let posns = 
          if List.length posns > 1 then
            let src = List.nth_exn posns (List.length posns - 2) in
            let dest = List.nth_exn posns (List.length posns - 1) in
            let last = { Pos.x = image_width /. 3.0; y = dest.y +. (dest.y -. src.y) } in
            (drop_last posns) @ [ last ]
          else 
            posns
        in
        Svg.path posns
      in
      let sibling_edge_positions = 
        let srcs = drop_last specs in
        let dests = List.drop specs 1 in
        let edges = List.map2_exn srcs dests ~f:(fun src dest -> 
            let pos_src = Spec.pos src in
            let pos_dest = Spec.pos dest in
            let right = pos_src.x > pos_dest.x in
            let pos_dest = 
              if right
              then { pos_dest with x = pos_dest.x +. (x_delta *. 2.0) }
              else { pos_dest with x = pos_dest.x -. (x_delta *. 2.0) }
            in
            pos_src, pos_dest, right
          )
        in
        edges
      in
      let sibling_edges = 
        List.map sibling_edge_positions ~f:(fun (src, dest, _) -> 
            Svg.path [src; dest]
          )
      in
      let sibling_nodes = 
        List.map sibling_edge_positions ~f:(fun (_, dest, right) -> 
            let color = "#8492A6" in
            let size = 12.0 in
            let center = 
              if right 
              then { Pos.x = dest.Pos.x -. 3.0; y = dest.y }
              else { Pos.x = dest.Pos.x +. 3.0; y = dest.y }
            in
            Svg.triangle ~radius:0.0 ~center ~width:size ~height:size ~color
          )
      in
      let nodes =
        List.filter_mapi specs ~f:(fun i spec ->
            let radius = 
              if i = 0 
              then 12.0 
              else 7.0 
            in
            match spec with
            | Spec.Node {pos; color} ->
                Some (Svg.circle ~radius ~color ~center:pos)
            | Spec.Account _ -> None )
      in
      hoverable state (
      Node.div [Style.just "flex items-center"]
      [ Node.div [Style.(render (of_class "mw5" + Html.grouping_style))]
          ( Svg.main
              ~width:(image_width +. left_offset)
              ~height:(image_height +. top_offset)
              (edges :: sibling_edges @ nodes @ sibling_nodes)
          :: Option.to_list account )
      ; Html.Tooltip.create ~active:(Tooltip_stage.(equal Account_state state.State.tooltip_stage)) ~arity:`Right ~text:"To know the state of a particular account in Coda, a client needs the database merkle root from the protocol state, a merkle path, and the account properties. Because the database is a merkle root, this information is sufficient to determine the balance in an account. And because the snark, protocol state, merkle path, and account state are of a fixed size, Coda can provide a full proof of the state of an account with just a constant (~20kb) of data."
      ]) Tooltip_stage.Account_state []
    in
    rendered

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

module Image = struct
  let draw ?(style= Style.empty) ~src ~alt xy =
    let inline_style =
      match xy with
      | `Fixed_width x ->
          let xStr = Int.to_string x in
          Printf.sprintf "width:%spx" xStr
      | `Fixed (x, y) ->
          let xStr = Int.to_string x in
          let yStr = Int.to_string y in
          Printf.sprintf "width:%spx;height:%spx" xStr yStr
      | `Free -> ""
    in
    (* TODO: Why can't we make <img> tags with VirtualDOM!! *)
    let img = Node.create "img" in
    let src = Attr.create "src" src in
    let alt = Attr.create "alt" alt in
    img
      [Attr.style_css inline_style; Style.render style; src; alt]
      []
end


(** A Pane is full-width on mobile and on desktop
 * On desktop it's 1/3 (thin) or 2/3 (wide)
 *)
module Pane = struct
  let create ?minwidth ~content () =
    let open Node in
    let minwidth =
      match minwidth with
      | None -> Style.empty
      | Some `Wide -> Style.of_class "minw6-ns"
      | Some `Thin -> Style.of_class "minw5-ns"
    in
    div [Style.(render ((of_class "flex ml3 mr3 pv3  overflow-hidden") + minwidth))]
      [content]
end

module Button = struct
  let create ~f ~button_hint ~extra_style =
    let open Node in
    button [
      Style.(
            render
              ( of_class
                  "user-select-none hover-bg-blacklike white no-underline ttu \
                   tracked bg-silver icon-shadow ph3 pv3 br4 tc lh-copy"
              + extra_style ))
    ; Attr.on_click f
    ] [text button_hint]

  let cta ~button_hint ~f =
    create ~button_hint ~extra_style:(Style.of_class "f4") ~f
end

let images = "/web-demo-art/"

let image_url s = images ^ s

module Breadcrumbs = struct
  let create state =
    let open Node in
    let select i _ = 
      let app_stage = 
        match i with 
        | 0 -> App_stage.Intro
        | 1 -> Problem 
        | 2 -> Coda    
        | 3 -> Mission 
        | 4 -> App     
        | _ -> failwith "unexpected case"
      in 
      !g_update_state_and_vdom { state with State.app_stage=app_stage };
      Event.Ignore
    in
    let selected = 
      match state.app_stage with
      | App_stage.Intro -> 0
      | Problem -> 1
      | Coda -> 2
      | Mission -> 3
      | App -> 4
    in
    let empty_dot i = 
       div
        [Attr.on_click (select i); Attr.class_ "breadcrumb"] 
        [] 
    in
    let full_dot = 
       div
        [Attr.class_ "breadcrumb full"] 
        [] 
    in
    let dots = 
      List.init 5 ~f:(fun i -> 
          if i = selected 
          then full_dot
          else empty_dot i)
    in
    let bread_button action title = 
      div [Attr.on_click action; Attr.class_ "bread_button"] [text ("• " ^ title)]
    in
    let last = 
      match state.app_stage with
      | App -> bread_button (select 0) "start over"
      | _ -> bread_button (select 4) "skip"
    in
    div [] (dots @ [ last ])
end

module Story = struct
  module Cell = struct
    let next state target =
      match state.State.app_stage with 
      | App -> 
        Button.cta ~button_hint:"Follow our progress" ~f:(fun _ -> 
          !g_update_state_and_vdom { state with State.app_stage=target };
          Event.Ignore
        )
      | _ -> 
        Button.cta ~button_hint:"Next" ~f:(fun _ -> 
          !g_update_state_and_vdom { state with State.app_stage=target };
          Event.Ignore
        )

    let style =
      Style.of_class "ml3-ns mw7 h6 flex flex-column justify-between bg-snow"

    let bottom state next_state =
      let open Node in
      div []
        [ next state next_state
        ; Breadcrumbs.create state
        ]

    let terminal state ~heading ~copy ~next_state =
      let open Node in
      div [Style.(render style)]
        [ h1 [ Style.(render (of_class "f2 m0 mt2"))] [text heading]
        ; div [] [text copy]
        ; bottom state next_state
        ]

    let comic state ~copy ~strip ~next_state =
      let open Node in
      div [Style.(render style)]
        [ div [Style.(render (of_class "mt2"))] [text copy]
        ; strip
        ; bottom state next_state
        ]

    let simple_comic state ~copy ~img ~alt ~next_state =
      let open Node in
      comic state ~copy ~strip:(
          div [Style.(render (of_class "flex flex-column items-end"))]
            [ Image.draw ~style:(Style.of_class "mw6-ns") ~src:img ~alt `Free]) ~next_state

  end

  let create state =
    let open Node in
    let terminal = Cell.terminal state in
    let comic = Cell.comic state in
    let simple_comic = Cell.simple_comic state in
    match state.app_stage with
    | Intro -> terminal ~heading:"Coda Protocol Demo" ~copy:"This demo is showing a live browser verified copy of the Coda Protocol Testnet.\n\nCoda enables you to be absolutely certain..." ~next_state:Problem
    | Problem -> simple_comic
      ~copy:"Cryptocurrencies today make users give up control to parties running powerful computers, bringing them out of reach of the end user." ~img:(image_url "problem.png") ~alt:"Hand with big blockchain" ~next_state:Coda
    | Coda -> comic
        ~copy:"Coda is a new cryptocurrency that puts control back in the hands of the users. Its resource requirements are so low it runs in your browser."
        ~strip:(
          div [Style.(render (of_class "flex justify-between"))]
            [ Image.draw ~src:(image_url "compare-outlined.svg") ~alt:"Others vs Coda" (`Fixed_width 200)
            ; Image.draw ~src:(image_url "your-hands.png") ~alt:"A user of Coda" (`Fixed_width 400)
            ]
        )
        ~next_state:Mission
    | Mission -> simple_comic
        ~copy:"This is our first step towards putting users in control of the computer systems they interact with and back in control of their digital lives."
        ~img:(image_url "net-hand.png")
        ~alt:"Hand with the work"
        ~next_state:App
    | App -> terminal
        ~heading:"Coda Protocol Demo"
        ~copy:"This demo is showing a live browser..."
        ~next_state:Problem
end

module Container = struct
  let create ~configuration =
    let open Node in
    let (left_content, left_width), right_content, primary_content =
      match configuration with
      | `Left_primary ((left, left_width), right) ->
        ((left, left_width), right, left)
      | `Right_primary ((left, left_width), right) ->
        ((left, left_width), right, right)
    in
    Mobile_switch.create
      ~not_small:(
        div [Style.(render @@ of_class "flex w-100")]
          [ Pane.create ~content:left_content  ~minwidth:left_width ()
          ; Pane.create ~content:right_content ()
          ]
      )
      ~small:(
        Pane.create ~content:primary_content ()
      )

end

let state_html
    state
     =
     let { State.verification
         ; app_stage=_
         ; tooltip_stage= _
         ; download_progress
         ; chain=
             { protocol_state=
                 {previous_state_hash; blockchain_state; consensus_state}
             ; ledger
             ; proof } } = state in
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
    Style.of_class @@
      match verification with
      | `Complete (Ok _) -> "grass-gradient b-grass"
      | `Complete (Error _) -> "proof"
      | `Pending _ -> "proof verifying shake shake-constant"
  in
  let proof_style = Style.(proof_style + (of_class "wb")) in
  let state_record =
    let open Html.Record in
    create
      [ [ create_entry "previous_state_hash"
            (field_to_base64 previous_state_hash) ]
      ; [ create_entry "length" (Length.to_string length)]
      ; [ create_entry "timestamp" timestamp]
      ; [ create_entry "locked_ledger_hash" (field_to_base64 ledger_hash)]
      ; [ create_entry "staged_ledger_hash"
            (field_to_base64 ledger_builder_hash.ledger_hash) ] ]
  in
  let hoverable = hoverable state in
  let _ = ledger in
  let state_explorer =
    match download_progress with
    | Progress _ -> div [] [Node.text "downloading..."]
    | Done -> 
    div [class_ "state-explorer flex items-center"]
      [ div [class_ "state-with-proof mw7 mr4"]
          [ hoverable(Html.Record.render
            ~grouping:`Together
            ~tooltip:(`Left (Html.Tooltip.create ~active:(Tooltip_stage.(equal Proof state.State.tooltip_stage)) ~arity:`Left ~text:"While other cryptocurrencies require downloading and verifying a lengthy, ever growing blockchain, the Coda network incrementally produces zk-SNARK proofs, which serve as cryptographic certifications of the database. The Coda testnet is sending a copy of this snark live to a client in your browser, which can use the snark to verify the protocol state."))
            (Html.Record.create
            [[ create_entry ~important:true ~extra_style:proof_style "blockchain_SNARK" (to_base64 (module Proof) proof)
            ]]) `Thin) Tooltip_stage.Proof  []
          ; hoverable (Html.Record.render ~grouping:`Together ~tooltip:(`Left (Html.Tooltip.create ~active:(Tooltip_stage.(equal Blockchain_state state.State.tooltip_stage)) ~arity:`Left ~text:"Coda's protocol state is composed of the consensus state and the database state. Our test network is currently using \"proof of signature\", where producing a valid snark for an updated protocol state requires a priveleged private key (Coda will use a fully open consensus protocol in later versions of the testnet). The staged and locked ledger hashes represent roots of merkle databases. Changes to accounts are reflected immediately in the staged ledger hash. The locked ledger hash is set from the staged ledger hash periodically, as snark proofs are computed.")) state_record `Wide) Tooltip_stage.Blockchain_state []
          ]
      ; hoverable
          ( let tree = Sparse_ledger_lib.Sparse_ledger.tree ledger in
            Mobile_switch.create
             ~not_small:(merkle_tree num_layers_to_show_desktop state tree)
             ~small:(merkle_tree num_layers_to_show_mobile state tree) )
           Tooltip_stage.Account_state [Style.just "mw7"]
      ] 
  in
  (*let header = div [class_ "flex items-center mw9 center mt3 mt4-m mt5-l mb4 mb5-m ph6-l ph5-m ph4 mw9-l"] [ Node.create "img" [Attr.create "width" "170px" ;Attr.create "src" "logo.svg"] [] ]*)
  (*in*)
  state_explorer
  (*div [] [*)
    (*header*)
  (*; div [class_ "flex items-center mw9 center mt3 mt4-m mt5-l mb4 mb5-m ph6-l ph5-m ph4 mw9-l"]*)
      (*[ state_explorer ]*)
  (*]*)

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
  g_update_state_and_vdom := update_state_and_vdom;
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
            let new_state = { !state with verification=`Pending id; chain } in
            update_state_and_vdom new_state ;
            Verifier.send_verify_message verifier (chain, id) ) ) )
  in
  loop () ;
  Dom_html.window ## setInterval (Js.wrap_callback (fun _ -> loop ())) 5_000.

let _ =
  main
    ~get_data:(fun ~on_result ->
      get_account () on_result (fun e -> 
      Firebug.console##log (Error.to_string_hum e)
      ) )
    ~render:state_html
