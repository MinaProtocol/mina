open Core
open Async
open Stationary
open Common

let heading =
  let open Html_concise in
  h1 [] [text "CODA"]

module Code_snippet = struct
  open Html_concise

  let create ~lines =
    let formatted = List.map lines ~f:(fun line -> "$ " ^ line) in
    let interspersed =
      List.map formatted ~f:text |> List.intersperse ~sep:(node "br" [] [])
    in
    div
      [ Style.just
          "bg-superdarksnow darksnow menlo b lh-copy f6 ph3 pv3 br3 \
           shadow-inset1" ]
      [p [Style.just "ml0 mr0 mt0 mb0 wb"] interspersed]
end

module Cta_description = struct
  open Html_concise

  let cta button_text =
    div
      [Style.just "flex db-ns justify-center"]
      [ a
          [ Attribute.href "https://github.com/CodaProtocol/coda"
          ; Style.just "no-underline" ]
          [ div
              [ Style.just
                  "flex items-center pv3 ph3 bg-grass br-pill white bold link"
              ]
              [ node "i" [Style.just "fab fa-github f2"] []
              ; span [Style.just "ml3 fw7 f4 ibmplex"] [text button_text] ] ]
      ]

  let copy_view copy ~extra_style =
    p
      [Style.(render (of_class "mw57 ibmplex fw4 lh-copy" + extra_style))]
      (List.map copy ~f:(function
        | `Normal s -> span [] [text s]
        | `Bold s -> span [Style.just "fw6"] [text s] ))

  let create ~button_text ~copy ~link =
    Mobile_switch.create
      ~not_small:
        (div
           [Style.just "flex justify-between mt5 mb5"]
           [copy_view ~extra_style:(Style.of_class "mt0") copy; cta button_text])
      ~small:
        (div [Style.just "mt4 mb5"]
           [cta button_text; copy_view ~extra_style:(Style.of_class "mt4") copy])
end

module Get_started = struct
  open Html_concise

  module Item = struct
    let chevron =
      div
        [Style.just "ocean o-40 mr3 ml4-ns"]
        [node "i" [Style.just "f1 fas fa-chevron-right"] []]

    let title s =
      h2 [Style.just "w310px ibmplex f2 fw5 ocean mt0 mb4 mb0-ns"] [text s]

    let copy s =
      span [Style.just "mt2 mw55 ibmplex lightsilver fw4 lh-copy"] [text s]

    let create ~url ~name ~description =
      a
        [Attribute.href url; Style.just "no-underline pointer"]
        [ Mobile_switch.create
            ~not_small:
              (div
                 [Style.just "flex items-center justify-between mt4 mb4"]
                 [ title name
                 ; div [Style.just "w-60"] [copy description]
                 ; chevron ])
            ~small:
              (div []
                 [ div
                     [Style.just "flex justify-between mt4"]
                     [title name; chevron]
                 ; div [Style.just "mb4"] [copy description] ]) ]
  end

  let create ~items =
    div [] (List.intersperse items ~sep:(hr [Style.render Styles.clean_hr]))
end

let footer = Html.text "Footer"

let content =
  let open Html_concise in
  let content =
    div
      [Style.just "mw7 pv3 center ph3 blacklike"]
      [ Code_snippet.create
          ~lines:
            [ "docker run -d --name coda codaprotocol/coda:demo"
            ; "docker exec -it coda /bin/bash"
            ; "watch coda client status" ]
      ; div [Style.just "ph2"]
          [ Cta_description.create ~button_text:"View on GitHub"
              ~copy:
                [ `Normal
                    "Coda is a cryptocurrency that can scale to millions of \
                     users and thousands of transactions per second while \
                     remaining decentralized. Any client, including \
                     smartphones, will be able to"
                ; `Bold "instantly validate the state of the ledger." ]
              ~link:"https://github.com/CodaProtocol/coda"
          ; Get_started.(
              create
                ~items:
                  [ Item.create
                      ~url:
                        "https://github.com/CodaProtocol/coda/blob/master/docs/demo.md"
                      ~name:"Get Started"
                      ~description:
                        "Spin up a local testnet, send payments, and learn \
                         how to interact with the Coda client"
                  ; Item.create
                      ~url:
                        "https://github.com/CodaProtocol/coda/blob/master/CONTRIBUTING.md"
                      ~name:"Contribute"
                      ~description:
                        "Join our open source community, work on issues, and \
                         learn how we use novel cryptography to create a \
                         scalable cryptocurrency network."
                  ; Item.create
                      ~url:
                        "https://github.com/CodaProtocol/coda/blob/master/docs/lifecycle_of_a_payment_lite.md"
                      ~name:"Learn More"
                      ~description:
                        "Dive into the cutting-edge research and engineering \
                         that underlies Coda’s technology" ]) ] ]
  in
  wrap_simple
    ~body_style:(Style.of_class "bg-offwhite")
    ~navbar:Navbar.simple_nav ~page_label:"open-source" ~append_footer:true
    ~show_newsletter:false content
