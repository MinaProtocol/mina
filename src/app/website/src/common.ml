open Core
open Async
open Stationary

let analytics_handler label =
  let handler =
    sprintf {js|_gaq.push(['_trackEvent', 'coda', 'click', '%s', '0']);|js}
      label
  in
  Attribute.create "onclick" handler

module Styles = struct
  let copytext = Style.of_class "lh-copy f4 fw3 silver"

  let heading_style = ["ttu"; "tracked"; "fw4"]
end

module Image = struct
  let draw ?(style = Style.empty) src xy =
    let inline_style =
      match xy with
      | `Fixed_width x ->
          let xStr = Int.to_string x in
          Printf.sprintf "max-width:%spx" xStr
      | `Fixed (x, y) ->
          let xStr = Int.to_string x in
          let yStr = Int.to_string y in
          Printf.sprintf "max-width:%spx;max-height:%spx" xStr yStr
      | `Free -> ""
    in
    ksprintf Html.literal
      {literal|<img style='%s' class="%s" src='%s'>|literal} inline_style
      (String.concat ~sep:" " style)
      src

  let placeholder ?(style = Style.empty) x y =
    let xStr = Int.to_string x in
    let yStr = Int.to_string y in
    draw ~style
      (Printf.sprintf "http://via.placeholder.com/%sx%s/8492A6/1F2D3D" xStr
         yStr)
      (*(`Fixed (x, y))*)
      `Free
end

module Image_positioning = struct
  type t = Left | Right
end

module Icon = struct
  let round = Style.of_class "br-100 dib"

  let round_shadowed = Style.(round + of_class "icon-shadow")

  let empty = Html_concise.div [] []

  let placeholder x y = Html_concise.(Image.placeholder ~style:round x y)

  let investor name ext =
    let ext = match ext with `Jpg -> "jpg" | `Png -> "png" in
    Image.draw ~style:round_shadowed
      (Printf.sprintf "/static/img/investors/%s"
         (String.concat ~sep:"." [name; ext]))
      (`Fixed (50, 50))

  let person name =
    Image.draw ~style:round_shadowed
      (Printf.sprintf "/static/img/%s" (name ^ ".jpg"))
      `Free
end

module Spacing = struct
  let side_padding = Style.of_class "ph6-l ph5-m ph4 mw9-l"
end

module Visibility = struct
  let no_mobile = Style.of_class "dn db-ns"

  let only_large = Style.of_class "dn db-l"

  let only_mobile = Style.of_class "db dn-ns"
end

module Mobile_switch = struct
  let create ~not_small ~small =
    let open Html_concise in
    div []
      [ div [Style.render Visibility.no_mobile] [not_small]
      ; div [Style.render Visibility.only_mobile] [small] ]
end

let title_string s = sprintf "Coda - %s" s

let analytics =
  Html.literal
    {literal|
<script async src="https://www.googletagmanager.com/gtag/js?id=UA-115553548-2"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'UA-115553548-2');
</script>
|literal}

module Links = struct
  let label (_, _, x) = x

  let mail = ("contact@o1labs.org", "mailto:contact@o1labs.org", "mail")

  let o1www = ("o1labs.org", "https://o1labs.org", "o1www")

  let twitter = ("Twitter", "https://twitter.com/codaprotocol", "twitter")

  let github = ("GitHub", "https://github.com/o1-labs", "github")

  let reddit = ("Reddit", "https://reddit.com/r/coda", "reddit")

  let blog =
    ( "Blog"
    , "https://medium.com/codaprotocol/coda-keeping-cryptocurrency-decentralized-e4b180721f42"
    , "blog" )

  let telegram = ("Telegram", "https://t.me/codaprotocol", "telegram")

  let tos = ("Terms of Service", "/tos.html", "tos")

  let privacy = ("Privacy Policy", "/privacy.html", "privacy")

  let hiring = ("We're Hiring", "jobs.html", "hiring")

  let jobs = ("Jobs", "jobs.html", "jobs")

  let testnet = ("Testnet", "testnet.html", "testnet")
end

module Input_button = struct
  let hack_create_i'm_tired ~label ~button_hint ~extra_style ~url ~new_tab () =
    let open Html in
    let open Html_concise in
    let button_node =
      match button_hint with
      | `Text button_hint -> text button_hint
      | `Node n -> n
    in
    node "a"
      ( [ href url
        ; Style.(
            render
              ( of_class
                  "user-select-none hover-bg-black white no-underline ttu \
                   tracked bg-silver ph2 icon-shadow br4 tc lh-copy"
              + extra_style ))
        ; analytics_handler label ]
      @ if new_tab then [Attribute.create "target" "_blank"] else [] )
      [button_node]

  let create ~label ~button_hint ~extra_style ~url ~new_tab () =
    let open Html in
    let open Html_concise in
    let button_node =
      match button_hint with
      | `Text button_hint -> text button_hint
      | `Node n -> n
    in
    node "a"
      ( [ href url
        ; Style.(
            render
              ( of_class
                  "user-select-none hover-bg-black white no-underline ttu \
                   tracked bg-silver icon-shadow ph3 pv3 br4 tc lh-copy"
              + extra_style ))
        ; analytics_handler label ]
      @ if new_tab then [Attribute.create "target" "_blank"] else [] )
      [button_node]

  let cta ?(extra_style = "") ?(new_tab = true) ~label ~button_hint ~url () =
    let open Html in
    let open Html_concise in
    create ~button_hint:(`Text button_hint) ~new_tab
      ~extra_style:(Style.of_class ("f3 ph4 pv3 " ^ extra_style))
      ~label ~url ()

  let fixed ?(new_tab = true) ~button_hint () =
    let open Html in
    let open Html_concise in
    create ~button_hint:(`Text button_hint)
      ~extra_style:(Style.of_class "f5 bottomrightfixed br--top")
      ~new_tab ~label:"fixed" ~url:"https://goo.gl/forms/PTusW11oYpLKJrZH3" ()
end

module Navbar = struct
  let navbar current_page =
    let open Html in
    let open Html_concise in
    let a style url children label open_new_tab =
      let extra_attrrs =
        if open_new_tab then [Attribute.create "target" "_blank"] else []
      in
      node "a"
        ( [ href url
          ; analytics_handler (sprintf "navbar-%s" label)
          ; Style.(render (style + of_class "hover-link")) ]
        @ extra_attrrs )
        children
    in
    let coda style =
      div [Style.render style]
        [ node "img"
            [ Attribute.create "width" "170px"
            ; Attribute.src "/static/img/logo.svg" ]
            [] ]
    in
    let maybe_no_underline label =
      if current_page = label then Style.empty
      else Style.of_class "no-underline"
    in
    let a' ?(open_new_tab = false) ?(style = Style.empty) url children label =
      a
        Style.(
          of_class "fw3 silver tracked ttu" + style + maybe_no_underline label)
        url children label open_new_tab
    in
    div
      [ Style.(
          render
            ( of_class "flex items-center mw9 center mt3 mt4-m mt5-l mb4 mb5-m"
            + Spacing.side_padding )) ]
      [ div [class_ "w-50"] [a [] "./" [coda Style.empty] "coda-home" false]
      ; div
          [class_ "flex justify-around w-75"]
          [ (let name, url, label = Links.blog in
             a' ~style:Visibility.no_mobile ~open_new_tab:true url [text name]
               label)
          ; (let name, url, label = Links.testnet in
             a' url [text name] label)
          ; a' ~style:Visibility.only_large "index.html#community"
              [text "Community"] "community"
          ; (let name, url, label = Links.jobs in
             a' url [text name] label)
          ; a' ~style:Visibility.only_large ~open_new_tab:true
              "https://goo.gl/forms/PTusW11oYpLKJrZH3" [text "Sign up"]
              "sign-up" ] ]
end

module Footer = struct
  let title_style = Style.(Styles.heading_style + of_class "black f6 tl")

  module Newsletter = struct
    let create ~copy ~button_hint =
      let open Html_concise in
      (*div []*)
      (*[ h2 [Style.(render title_style)] [text "Newsletter"]*)
      (*; p [Style.(render (Styles.copytext + of_class "f6"))] [text copy]*)
      (*; div [] [Input_button.create ~button_hint]*)
      (*]*)
      div [] [Input_button.fixed ~button_hint ()]
  end
end

module Compound_chunk = struct
  let create ?(variant = `With_image) ~important_text ~image ~image_positioning
      () =
    let open Html_concise in
    match image with
    | None ->
        div
          [class_ "flex items-center mb5 fixed_no_img_height"]
          [important_text]
    | Some image ->
        let left, right =
          match image_positioning with
          | Image_positioning.Left -> (image, important_text)
          | Right -> (important_text, image)
        in
        Mobile_switch.create
          ~not_small:
            (div
               [class_ "flex items-center mb5"]
               [ div [class_ "flex w-50"] [div [class_ "mw6"] [left]]
               ; div [class_ "flex w-50"] [div [class_ "center"] [right]] ])
          ~small:
            (div
               [class_ "w-100 center mb4"]
               ( match variant with
               | `With_image ->
                   [ div [class_ "flex justify-center mb3"] [image]
                   ; important_text ]
               | `No_image_on_small -> [important_text] ))
end

module Section = struct
  let section' ?(heading_size = `Normal) ?heading ?(footer = false) content
      scheme =
    let open Html_concise in
    let color, bg_color =
      match scheme with
      | `Light -> ("black", "bg-white")
      | `Dark -> ("silver", "bg-snow")
    in
    let heading_font =
      match heading_size with `Normal -> "f5" | `Large -> "f3"
    in
    let heading_style =
      let open Style in
      Styles.heading_style + of_class color
      + of_class ("tc mt0 mb4 " ^ heading_font)
    in
    let maybe_id =
      match heading with
      | Some heading ->
          let section_id =
            String.split ~on:' ' (String.lowercase heading) |> List.hd_exn
          in
          [id section_id]
      | None -> []
    in
    let heading =
      Option.map heading ~f:(fun heading ->
          h2 [Style.render heading_style] [text heading] )
    in
    let maybe_footer = if footer then ["bottom-footer"] else [] in
    div
      [Style.(render (["bxs-cb"; bg_color] + maybe_footer))]
      [ section
          ( [ Style.(
                render
                  ( ["section-wrapper"; "pv4"; "mw9"; "center"; "bxs-bb"]
                  + Spacing.side_padding )) ]
          @ maybe_id )
          ( match heading with
          | Some heading -> [heading; content]
          | None -> [content] ) ]

  let carousel ?heading ~pages ~scheme () =
    let open Html_concise in
    let carousel =
      let control_divs =
        List.mapi pages ~f:(fun i _ ->
            div
              [ id (Printf.sprintf "item-%d" i)
              ; Style.(render (of_class "control-operator ")) ]
              [] )
      in
      let controls =
        List.init (List.length pages) ~f:(fun i ->
            let skip =
              Mobile_switch.create
                ~not_small:
                  ( if i = 4 then
                    a
                      [Style.(render (of_class "jump")); href "#item-0"]
                      [text "start over"]
                  else
                    a
                      [Style.(render (of_class "jump")); href "#item-4"]
                      [text "skip"] )
                ~small:(div [] [])
            in
            let next =
              if i = 4 then
                let button_hint, label, url, new_tab =
                  ( "Follow us"
                  , "demo-follow-cta"
                  , "https://twitter.com/codaprotocol?lang=en"
                  , true )
                in
                let itag = Html.node "i" in
                let twitter =
                  itag
                    [ Style.just
                        "ml-1 ml-2-ns fab f1 f2-m f1-l fa-twitter mr3 mr2-m \
                         mr3-l" ]
                    []
                in
                Mobile_switch.create ~small:(div [] [])
                  ~not_small:
                    (Input_button.hack_create_i'm_tired
                       ~button_hint:
                         (`Node
                           (div
                              [Style.just "flex items-center pv2 pr2 pl3 f3"]
                              [span [] [twitter]; span [] [text button_hint]]))
                       ~label ~url
                       ~extra_style:(Style.of_class "progress-button pv2")
                       ~new_tab ())
              else
                a
                  [ Style.(render (of_class "next-button"))
                  ; href (Printf.sprintf "#item-%d" (i + 1)) ]
                  [div [] [text "›"]]
            in
            div
              [ Style.(
                  render
                    (of_class "controls flex justify-left user-select-none"))
              ]
              [ div []
                  (List.mapi pages ~f:(fun j _ ->
                       let selected = if j = i then " selected" else "" in
                       a
                         [ href (Printf.sprintf "#item-%d" j)
                         ; Style.(
                             render (of_class ("control-button" ^ selected)))
                         ]
                         [Html.text {literal|•|literal}] ))
              ; skip
              ; next ] )
      in
      let items =
        List.map2_exn pages controls ~f:(fun page control ->
            div
              [Style.(render (of_class "item mt0 mb0 ml0 mr0"))]
              [page; control] )
      in
      div [Style.(render (of_class "gallery"))] (control_divs @ items)
    in
    section' ?heading carousel scheme

  let major_compound ?heading ~important_text ~image ~image_positioning ~scheme
      () =
    section' ?heading
      (Compound_chunk.create ~important_text ~image ~image_positioning ())
      scheme

  let major_text ?heading ~important_text ~scheme () =
    let open Html_concise in
    let content = div [class_ "center mw7"] [important_text] in
    section' ?heading content scheme

  let job_list ?heading ~important_text ~scheme () =
    Html_concise.(section' ?heading)

  let with_examples ?heading ~content ~examples ~scheme ~cta_hint ~cta_label
      ~cta_url () =
    section' ?heading
      (let open Html_concise in
      let top_style = Style.(Styles.copytext + of_class "mw6 tc center mb5") in
      let top =
        match content with
        | Some content -> p [Style.render top_style] [text content]
        | None -> div [class_ "dn"] []
      in
      let examples =
        List.map examples ~f:(fun e -> li [class_ "mb5 mw8 center"] [e])
      in
      div [class_ "with-examples"]
        [ top
        ; ul [class_ "list ph0"] examples
        ; div
            [class_ "flex justify-center"]
            [ Input_button.cta ~button_hint:cta_hint ~label:cta_label
                ~url:cta_url () ] ])
      scheme

  let investors ?heading ~investors ~scheme () =
    let content =
      let open Html_concise in
      div
        [class_ "flex justify-center"]
        [div [class_ "investors-grid mw8"] investors]
    in
    section' ?heading content scheme

  let footer ~about ~contact ~newsletter ~scheme =
    let content =
      let open Html_concise in
      Mobile_switch.create
        ~not_small:
          (div
             [class_ "flex justify-between"]
             [ div [class_ "w-25"] [about]
             ; div [class_ "w-25"] [contact]
             ; div [class_ ""] [newsletter] ])
        ~small:
          (div [class_ "flex flex-wrap"]
             [ div [class_ "w-100"] [newsletter]
             ; div [class_ "w-50"] [about]
             ; div [class_ "w-50"] [contact] ])
    in
    section' content scheme

  let footer' ?(fixed = false) ~links ~newsletter ~scheme =
    let content =
      let open Html_concise in
      let a style url children label =
        node "a"
          [ href url
          ; Style.(render (style + of_class "hover-link"))
          ; analytics_handler (sprintf "footer-%s" label)
          ; Attribute.create "target" "_blank" ]
          children
      in
      let cdots =
        span [class_ "dn"] []
        :: List.init
             (List.length links - 1)
             ~f:(fun _ -> span [class_ "f6 silver"] [text "·"])
        |> List.rev
      in
      div
        [class_ "flex justify-center tc mb4"]
        [ ul
            [Style.(render (of_class "list ph0"))]
            (List.map (List.zip_exn links cdots)
               ~f:(fun ((name, link, label), cdot) ->
                 li [class_ "mb2 dib"]
                   [ a
                       Style.(of_class "no-underline fw3 f6 silver")
                       link [text name] label
                   ; cdot ] ))
        ; newsletter ]
    in
    section' ~footer:fixed content scheme

  let cards ?heading ~cards ~scheme =
    let content =
      let open Html_concise in
      div [class_ "flex justify-center"] [div [class_ "card-grid mw9"] cards]
    in
    section' ?heading content scheme

  let three_subgroups ?heading ~groups ~scheme () =
    let a, b, c = groups in
    let a' : Html_concise.t = a in
    let content =
      let open Html_concise in
      Mobile_switch.create
        ~not_small:
          (let wrap c = div [class_ "ph1"] [c] in
           div []
             [ div [class_ "ph1 w-100"] [a']
             ; div [class_ "flex justify-around"] [wrap b; wrap c] ])
        ~small:
          (div [class_ "w-100"]
             [ div [class_ "mb4"] [a']
             ; div [class_ "w-100 mb4"] [c]
             ; div [class_ "w-100"] [b] ])
    in
    section' ?heading content scheme
end

let wrap ?(headers = []) ?(fixed_footer = false) ?title ~page_label sections =
  let title =
    Option.value_map ~default:"Coda Cryptocurrency Protocol" title
      ~f:title_string
  in
  let open Html in
  let open Attribute in
  let head =
    node "head" []
      ( headers
      @ [ literal "<meta charset=\"utf-8\">"
        ; literal
            "<meta name='viewport' content='width=device-width, \
             initial-scale=1'>"
        ; literal
            "<meta property='og:image' \
             content='https://codaprotocol.com/static/img/compare-outlined-png.png' \
             />"
        ; literal "<meta property='og:type' content='website' />"
        ; literal
            "<meta property='og:url' content='https://codaprotocol.com' />"
        ; ksprintf literal "<meta property='og:title' content='%s' />" title
        ; literal
            "<meta property='og:description' content='That means that no \
             matter how many transactions are performed, verifying the \
             blockchain remains inexpensive and accessible to everyone.' />"
        ; literal
            "<meta name='description' content='That means that no matter how \
             many transactions are performed, verifying the blockchain \
             remains inexpensive and accessible to everyone.' />"
        ; literal "<meta property='og:updated_time' content='1526001445' />"
        ; node "title" [] [text title]
        ; analytics
        ; link ~href:"https://fonts.googleapis.com/css?family=Rubik:500"
        ; link
            ~href:
              "https://fonts.googleapis.com/css?family=Alegreya+Sans:300,300i,400,400i,500,500i,700,700i,800,800i,900,900i"
        ; link ~href:"/static/css/common.css"
        ; link ~href:"/static/css/gallery.css"
          (* TODO: Only have this on demo *)
        ; literal
            {html|<link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.0.12/css/all.css" integrity="sha384-G0fIWCsCzJIMAVNQPfjH08cyYaUtMwjJwqiRKxxE/rx96Uroj1BtIQ6MLJuheaO9" crossorigin="anonymous">|html}
        ; literal
            {html|<link media='only screen and (min-device-width: 700px)' rel='stylesheet' href='/static/css/main.css'>|html}
        ; literal
            {html|<link media='only screen and (max-device-width: 700px)' rel='stylesheet' href='/static/css/mobile.css'>|html}
        ; literal
            {html|<link rel="icon" type="image/png" href="/static/favicon-32x32.png" sizes="32x32" />
      <link rel="icon" type="image/png" href="/static/favicon-16x16.png" sizes="16x16" />|html}
        ] )
  in
  let footer scheme =
    let open Footer in
    Section.footer' ~fixed:fixed_footer
      ~links:
        Links.
          [mail; o1www; twitter; github; reddit; telegram; tos; privacy; hiring]
      ~newsletter:
        (Newsletter.create ~copy:"We won’t spam you, ever."
           ~button_hint:"Join mailing list")
      ~scheme
  in
  let body =
    let navbar = Navbar.navbar page_label in
    let reified_sections =
      List.mapi
        (sections @ [footer])
        ~f:(fun i s -> s (if i % 2 = 0 then `Light else `Dark))
    in
    node "body"
      [class_ "metropolis bg-white black"]
      [ navbar
      ; node "div" [class_ "wrapper"] reified_sections
      ; literal {html|<script defer src="static/main.bc.js"></script>|html} ]
  in
  node "html" [] [head; body]
