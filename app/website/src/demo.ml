open Core
open Async
open Common
open Stationary

(* DEAD FOR NOW *)

module App_stage = struct
  type t =
    | Intro
    | Problem
    | Coda
    | Mission
    | App
  [@@deriving sexp]
end

let image_url s = "/static/img/testnet/" ^ s

module Story = struct
  module Cell = struct
    let next stage target =
      let url = "#" ^ (stage |> App_stage.sexp_of_t |> Sexp.to_string_hum) in
      match stage with 
      | App -> 
        Input_button.cta ~label:"Follow" ~button_hint:"Follow our progress" ~url
      | _ -> 
        Input_button.cta ~label:"next" ~button_hint:"Next" ~url

    let style =
      Style.of_class "ml3-ns mw7 h6 flex flex-column justify-between bg-snow"

    let bottom state next_state =
      let open Html_concise in
      div []
        [ next state next_state
        (*; Breadcrumbs.create state*)
        ]

    let terminal state ~heading ~copy ~next_state =
      let open Html_concise in
      div [Style.(render style)]
        [ h1 [ Style.(render (of_class "f2 m0 mt2"))] [text heading]
        ; div [] [text copy]
        ; bottom state next_state
        ]

    let comic state ~copy ~strip ~next_state =
      let open Html_concise in
      div [Style.(render style)]
        [ div [Style.(render (of_class "mt2"))] [text copy]
        ; strip
        ; bottom state next_state
        ]

    let simple_comic state ~copy ~img ~next_state =
      let open Html_concise in
      comic state ~copy ~strip:(
          div [Style.(render (of_class "flex flex-column items-end"))]
            [ Image.draw ~style:(Style.of_class "mw6-ns") img `Free ]) ~next_state

  end

  let create stage =
    let open Html_concise in
    let terminal = Cell.terminal stage in
    let comic = Cell.comic stage in
    let simple_comic = Cell.simple_comic stage in
    let open App_stage in
    match stage with
    | Intro -> terminal ~heading:"Coda Protocol Demo" ~copy:"This demo is showing a live browser verified copy of the Coda Protocol Testnet.\n\nCoda enables you to be absolutely certain..." ~next_state:Problem
    | Problem -> simple_comic
      ~copy:"Cryptocurrencies today make users give up control to parties running powerful computers, bringing them out of reach of the end user." ~img:(image_url "problem.png") ~next_state:Coda
    | Coda -> comic
        ~copy:"Coda is a new cryptocurrency that puts control back in the hands of the users. Its resource requirements are so low it runs in your browser."
        ~strip:(
          div [Style.(render (of_class "flex justify-between"))]
            [ Image.draw (image_url "compare-outlined.svg") (`Fixed_width 200)
            ; Image.draw (image_url "your-hands.png") (`Fixed_width 400)
            ]
        )
        ~next_state:Mission
    | Mission -> simple_comic
        ~copy:"This is our first step towards putting users in control of the computer systems they interact with and back in control of their digital lives."
        ~img:(image_url "net-hand.png")
        ~next_state:App
    | App -> terminal
        ~heading:"Coda Protocol Demo"
        ~copy:"This demo is showing a live browser..."
        ~next_state:Problem
end

module Container = struct
  let create () =
    let open Html_concise in
    div [Style.(render @@ of_class "w-100")]
      [ Story.create App_stage.Intro
      ; Image.placeholder 1024 800
      ]

end

let create () =
  Html_concise.(Container.create ())
