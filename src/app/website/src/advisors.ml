open Core
open Async
open Stationary
open Common

module Advisor = struct
  type t = {name: string; affiliation: string; image_url: string; bio: Html.t}

  let to_html {name; affiliation; image_url; bio} =
    let open Html_concise in
    div [class_ "advisor"]
      [ div [class_ "advisor-image"] [node "img" [Attribute.src image_url] []]
      ; div [class_ "advisor-info"]
          [ div [class_ "advisor-name"] [text name]
          ; div [class_ "advisor-affiliation"] [text affiliation]
          ; div [class_ "advisor-bio"] [bio] ] ]
end

type t = Advisor.t list

let to_html t =
  let open Html_concise in
  div
    [class_ "advisors bottom-section"]
    ( div [class_ "section-header"] [h2 [] [text "Advisors"]]
    :: List.map ~f:Advisor.to_html t )

let load () =
  let%map joe =
    let%map bio =
      Markdown.of_string
        {markdown|
Joseph Bonneau is an assistant professor of computer science at New York university.

A world expert in cryptography, his research interests include side-channel cryptanalysis, protocol verification, software obfuscation, and privacy in social networks. Recently, he focuses on the difficulty of successfully deploying cryptography and security technologies due to compatibility requirements, economic incentives, and human factors, and in particular
on secure communication tools, cryptocurrencies, password and web authentication, and HTTPS and PKI on the web.

He is a co-author of Bitcoin and Cryptocurrency Technologies, Princeton University Press 2016|markdown}
    in
    { Advisor.name= "Joseph Bonneau"
    ; affiliation= "NYU, EFF"
    ; image_url= "/static/img/bonneau.jpg"
    ; bio }
  and jill =
    let%map bio =
      Markdown.of_string
        {markdown|
Jill works with entities ranging from the IMF to Algorand to
bring cryptocurrency products to market.
Previously, Jill ran strategy at blockchain start up Chain, where she managed
initiatives with Nasdaq and State Street. Jill has conducted academic research
on cryptocurrency at the University of Oxford, where she focused on the economic
and political implications of bitcoin. Jill began her career as a credit trader at Goldman Sachs.
She holds a MSc from Magdalen College, Oxford, and an AB from Harvard, where she studied Classics.
|markdown}
    in
    { Advisor.name= "Jill Carlson"
    ; affiliation= ""
    ; image_url= "/static/img/carlson.jpg"
    ; bio }
  in
  [jill]
