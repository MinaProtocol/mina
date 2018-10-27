open Core
open Async
open Stationary
open Common

module Example = struct
  let create ~image ~image_positioning ~icon_image ~important_text =
    let open Html_concise in
    let info =
      div [class_ "example-info"]
        [div [class_ "mb3"] [icon_image]; div [class_ "mb2"] [important_text]]
    in
    let left, right =
      match image_positioning with
      | Image_positioning.Left -> (image, info)
      | Right -> (info, image)
    in
    let html =
      Mobile_switch.create
        ~small:
          (div []
             [ div [class_ "flex justify-center mb4"] [image]
             ; div [class_ "w-100"] [important_text] ])
        ~not_small:
          (div
             [class_ "flex items-center"]
             [ div [class_ "w-50 mr4-ns tr-ns"] [left]
             ; div [class_ "w-50 ml4-ns tl-ns"] [right] ])
    in
    html
end

module Important_title = struct
  open Html_concise

  let center h = div [class_ "flex justify-center"] [h]

  let to_string title =
    match title with `Left t -> t | `Center t -> t | `Right t -> t

  let position title =
    match title with
    | `Left _ -> ["tc tl-ns mt0 mr0 ml0"]
    | `Center _ -> ["tc center mt0"]
    | `Right _ -> ["tc tr-ns mt0 mr0 ml0"]

  let wrap title =
    match title with
    | `Left _ -> Fn.id
    | `Center _ -> center
    | `Right _ -> Fn.id

  let style title =
    Style.(of_class "dib mw6 m-none lh-copy f2 mb3 mb4-ns" + position title)

  let html title = h3 [Style.render (style title)] [text @@ to_string title]

  let content_style title = Style.(Styles.copytext + position title)
end

let marked_up_content content =
  List.map content ~f:(fun c ->
      let strs = String.split c ~on:'*' in
      let bold_style = Style.(render (of_class "fw6")) in
      List.mapi strs ~f:(fun i str ->
          if i mod 2 = 0 then Html_concise.text str
          else Html_concise.span [bold_style] [Html_concise.text str] ) )

module Important_text = struct
  let create ~title ~content ?(alt_content = None) () =
    let open Html_concise in
    let content_style, title_html =
      Important_title.(content_style title, html title)
    in
    let make_content content =
      let content_length = List.length content in
      div
        [Style.render content_style]
        (List.mapi content ~f:(fun i txt ->
             p
               (let open Style in
               let style =
                 (if i = 0 then of_class "mt0" else empty)
                 + if i = content_length - 1 then of_class "mb0" else empty
               in
               [render style])
               txt ))
    in
    div [class_ "important-text"]
      [ Mobile_switch.create
          ~not_small:(Important_title.wrap title title_html)
          ~small:(Important_title.center title_html)
      ; Mobile_switch.create ~not_small:(make_content content)
          ~small:(make_content (Option.value alt_content ~default:content)) ]
end

module Investor = struct
  let create name ext =
    let icon =
      let basename =
        String.split ~on:' ' (String.lowercase name) |> List.hd_exn
      in
      Icon.investor basename ext
    in
    let open Html_concise in
    div
      [class_ "flex justify-center"]
      [ div [class_ "ph2 ph3-ns"]
          [ div [class_ "flex justify-center w-100"] [icon]
          ; h4
              [ Style.(
                  render
                    ( Styles.heading_style
                    + of_class "tc w-100 silver fw5 force-word-breaks f8 f7-ns"
                    )) ]
              [text name] ] ]
end

module Link_list = struct
  let create ~orientation ~named xs =
    let open Html in
    let open Html_concise in
    let a style url children label =
      node "a"
        [ href url
        ; Style.(render (style + of_class "hover-link"))
        ; Common.analytics_handler label
        ; Attribute.create "target" "_blank" ]
        children
    in
    let title_style = Style.(Styles.heading_style + of_class "black f4 tl") in
    let heading =
      match orientation with
      | `Horizontal -> span [class_ "dn"] []
      | `Vertical -> text named
    in
    let maybe_vert_centering_style, orientation_style =
      match orientation with
      | `Horizontal ->
          let open Style in
          (of_class "flex items-center", of_class "flex justify-around w-100")
      | `Vertical -> Style.(empty, empty)
    in
    let inline_block_maybe =
      match orientation with
      | `Horizontal -> Style.of_class "dib-ns"
      | `Vertical -> Style.empty
    in
    div [class_ "w-100"]
      [ h2 [Style.(render title_style)] [heading]
      ; ul
          [Style.(render (orientation_style + of_class "list ph0"))]
          (List.map xs ~f:(fun (name, link, label) ->
               let icon n =
                 ksprintf Html.text
                   {literal|<i class="ml-1 ml-2-ns fab f1 f2-m f1-l fa-%s mr3 mr2-m mr3-l"></i>|literal}
                   n
               in
               let inline_block_maybe =
                 let open Style in
                 inline_block_maybe
                 + match link with `One _ -> empty | `Two _ -> of_class "dib"
               in
               let link, maybe_second_link =
                 match link with
                 | `One s -> (s, fun style -> span [class_ "dn"] [])
                 | `Two (next_name, s1, s2) ->
                     ( s1
                     , fun style ->
                         a
                           Style.(style + of_class "ml-5px")
                           s2 [Html.text next_name] label )
               in
               let name =
                 match name with
                 | `Icon n ->
                     [icon (String.lowercase n); span [] [text (" " ^ n)]]
                 | `Read n -> [Html.text ("📖 " ^ n)]
                 | `Watch n -> [Html.text ("🎥 " ^ n)]
                 | `Listen n -> [Html.text ("🎙️ " ^ n)]
                 | `Event n -> [Html.text n]
               in
               let link_style =
                 let open Style in
                 maybe_vert_centering_style
                 + of_class "dib no-underline fw3 f4 silver lh-copy"
               in
               li
                 [Style.(render (inline_block_maybe + of_class "mb3 mr3"))]
                 [ span [class_ "f4 lh-copy"]
                     [ a link_style link name label
                     ; maybe_second_link link_style ] ] )) ]
end

module Job_listing = struct
  let create ~title ~jobs ~scheme =
    let open Html_concise in
    let content_style, title_html =
      Important_title.(content_style title, html title)
    in
    let of_jobs (name, link) = (`Event name, `One (link ^ ".html"), name) in
    let link_list =
      [ Link_list.create ~named:"" ~orientation:`Vertical
          (List.map jobs ~f:of_jobs) ]
    in
    Section.section'
      (div [class_ "important-text"]
         [ Mobile_switch.create
             ~not_small:(Important_title.wrap title title_html)
             ~small:(Important_title.center title_html)
         ; div [class_ "ml4-ns"] link_list ])
      scheme
end

let home () =
  let top scheme =
    Section.major_compound
      ~important_text:
        ((* TODO: Make important text have paragraph *)
         Important_text.create
           ~title:(`Left "Keeping cryptocurrency decentralized")
           ~content:
             (marked_up_content
                [ "Coda is the first cryptocurrency protocol with a \
                   constant-sized blockchain. Coda compresses the entire \
                   blockchain into a tiny snapshot the size of a few tweets."
                ; "That means that no matter how many transactions are \
                   performed, verifying the blockchain remains inexpensive \
                   and accessible to everyone." ])
           ())
      ~image:
        (Some
           (Mobile_switch.create
              ~not_small:
                Html_concise.(
                  node "img"
                    [ Attribute.src "/static/img/compare-outlined.svg"
                    ; Attribute.create "width" "600px" ]
                    [])
              ~small:
                Html_concise.(
                  node "img"
                    [ Attribute.src "/static/img/compare-outlined.svg"
                    ; Attribute.create "width" "600px"
                    ; Attribute.create "height" "200px" ]
                    [])))
      ~image_positioning:Image_positioning.Right ~scheme ()
  in
  let testnet scheme =
    Section.major_text ?heading:(Some "Alpha testnet")
      ~important_text:
        (Important_text.create ~title:(`Center "")
           ~content:
             Html_concise.
               [ [ text
                     "We're excited to announce our alpha testnet. Check out "
                 ; a
                     [href "./testnet.html"; Style.(render (of_class "silver"))]
                     [text "this page"]
                 ; text " to learn more and get involved." ] ]
           ())
      ~scheme ()
  in
  let mission scheme =
    Section.major_text ?heading:(Some "Our Mission")
      ~important_text:
        (Important_text.create
           ~title:(`Center "We're making the world legible at a glance")
           ~content:
             (marked_up_content
                [ "Coda is a cryptocurrency that can\n\
                   scale to millions of users and thousands of transactions \
                   per second while\n\
                   remaining decentralized. Any client, including \
                   smartphones, will be\n\
                   able to instantly validate the state of the ledger. This \
                   is in service of our\n\
                   goal to make software transparent, legible, and respectful."
                ])
           ())
      ~scheme ()
  in
  let examples =
    [ Example.create
        ~image:(Image.draw "/static/img/proof-chain.svg" `Free)
        ~image_positioning:Image_positioning.Left ~icon_image:Icon.empty
        ~important_text:
          (Important_text.create ~title:(`Left "Compact blockchain")
             ~content:
               (marked_up_content
                  [ "Coda uses recursive composition of zk-SNARKs to compress \
                     the whole\n\
                     blockchain down to the size of a few tweets."
                  ; "No one needs to store\n\
                     or download transaction history in order to verify the \
                     blockchain." ])
             ())
    ; Example.create
        ~image:(Image.draw "/static/img/phone.svg" `Free)
        ~image_positioning:Image_positioning.Right ~icon_image:Icon.empty
        ~important_text:
          (Important_text.create ~title:(`Right "Instant sync")
             ~content:
               (marked_up_content
                  [ "Coda syncs instantly, allowing you to verify the \
                     blockchain even on a mobile phone. \n\
                     Interact with the blockchain anywhere." ])
             ()) ]
  in
  let job_examples =
    [ Example.create
        ~image:(Image.draw "/static/img/lambda.svg" `Free)
        ~image_positioning:Image_positioning.Left ~icon_image:Icon.empty
        ~important_text:
          (Important_text.create ~title:(`Left "Functional programming")
             ~content:
               (marked_up_content
                  [ "A cornerstone of our approach is a focus on building\n\
                     reliable software through the use of statically-typed \
                     functional programming languages."
                  ; "This is reflected in our OCaml codebase and style of\n\
                     structuring code around DSLs, as well as in the design \
                     of languages we're developing for Coda." ])
             ())
    ; Example.create
        ~image:(Image.draw "/static/img/crypto.svg" `Free)
        ~image_positioning:Image_positioning.Right ~icon_image:Icon.empty
        ~important_text:
          (Important_text.create ~title:(`Left "Cryptography and mathematics")
             ~content:
               (marked_up_content
                  [ "We're applying advanced cryptography, building on \
                     fundamental research in computer science and mathematics."
                  ])
             ())
    ; Example.create
        ~image:(Image.draw "/static/img/network.svg" `Free)
        ~image_positioning:Image_positioning.Left ~icon_image:Icon.empty
        ~important_text:
          (Important_text.create ~title:(`Left "Distributed systems")
             ~content:
               (marked_up_content
                  [ "We implement state-of-the-art\n\
                     consensus protocols and have developed\n\
                     frameworks for describing distributed systems, enabling \
                     us to quickly\n\
                     iterate." ])
             ()) ]
  in
  let protocol_design scheme =
    Section.with_examples ?heading:(Some "Protocol Design") ~content:None
      ~examples ~scheme ~cta_hint:"Whitepaper Draft"
      ~cta_label:"whitepaper-cta"
      ~cta_url:"/static/coda-whitepaper-05-10-2018-0.pdf" ()
  in
  let community scheme =
    let social_list orientation =
      let open Links in
      let icon_of (n, u, l) = (`Icon n, `One u, l) in
      Link_list.create ~named:"Social"
        (List.map ~f:icon_of [reddit; telegram; twitter])
        ~orientation
    in
    Section.three_subgroups ?heading:(Some "Community")
      ~groups:
        ( Mobile_switch.create
            ~not_small:(social_list `Horizontal)
            ~small:(social_list `Vertical)
        , Link_list.create ~named:"Articles" ~orientation:`Vertical
            [ ( `Read "Keeping Cryptocurrency Decentralized"
              , `One
                  (let _, u, _ = Links.blog in
                   u)
              , "blogpost-main" )
            ; ( `Read "Coindesk: This Blockchain Tosses Blocks"
              , `One
                  "https://www.coindesk.com/blockchain-tosses-blocks-naval-metastable-back-twist-crypto-cash/"
              , "coindesk-blogpost" )
            ; ( `Read "TokenDaily: Deep Dive with O(1) on Coda Protocol"
              , `One
                  "https://www.tokendaily.co/p/q-as-with-o-1-on-coda-protocol"
              , "tokendaily-ama" ) ]
        , Link_list.create ~named:"Media" ~orientation:`Vertical
            [ ( `Watch "Hack Summit 2018: Coda Talk"
              , `One "https://www.youtube.com/watch?v=eWVGATxEB6M"
              , "hack-summit" )
            ; ( `Listen "Token Talks - Interview with Coda"
              , `One "https://simplecast.com/s/17ed0e8d"
              , "token-talk" )
            ; ( `Watch "A High-Level Language for Verifiable Computation"
              , `One "https://www.youtube.com/watch?v=gYn6mTwJriw"
              , "snarky1" )
            ; ( `Watch "Snarky, a DSL for Writing SNARKs"
              , `One "https://www.youtube.com/watch?v=h0PUVR0s6Vg"
              , "snarky2" ) ] )
      ~scheme ()
  in
  let jobs scheme =
    Section.with_examples ?heading:(Some "Jobs")
      ~content:
        (Some
           "We're hiring engineers to work on exciting problems in \
            cryptography, programming languages, and distributed systems, \
            though by no means do applicants already need to be experts in \
            these fields. We are committed to building a diverse, inclusive \
            company. People of color, LGBTQIA individuals, women, and people \
            with disabilities are strongly encouraged to apply.")
      ~examples:job_examples ~scheme ~cta_hint:"Apply Now"
      ~cta_label:"apply-cta"
      ~cta_url:
        (let _, u, _ = Links.jobs in
         u)
      ()
  in
  let investors scheme =
    Section.investors ?heading:(Some "Investors")
      ~investors:
        (let open Investor in
        let c = create in
        [ c "Metastable" `Png
        ; c "Polychain Capital" `Jpg
        ; c "ScifiVC" `Png
        ; c "Dekrypt Capital" `Png
        ; c "Electric Capital" `Png
        ; c "Curious Endeavors" `Jpg
        ; c "Kindred Ventures" `Png
        ; c "Caffeinated Capital" `Png
        ; c "Naval Ravikant" `Png
        ; c "Elad Gil" `Jpg
        ; c "Linda Xie" `Jpg
        ; c "Fred Ehrsam" `Jpg
        ; c "Jack Herrick" `Jpg
        ; c "Nima Capital" `Png
        ; c "Charlie Noyes" `Png
        ; c "O Group" `Png ])
      ~scheme ()
  in
  let%map core_team = Team.core () in
  let team heading members scheme =
    Section.cards ?heading:(Some heading)
      ~cards:(List.map members ~f:Team.Member.to_html)
      ~scheme
  in
  let sections =
    [ top
    ; testnet
    ; mission
    ; protocol_design
    ; community
    ; team "Team" core_team
    ; jobs
    ; investors ]
  in
  wrap ~page_label:"" sections

let positions =
  [ ("Lead Designer", "lead-designer")
  ; ("Protocol Engineer", "protocol-engineer") ]

let jobs () =
  let top scheme =
    let open Html_concise in
    Job_listing.create ~scheme ~title:(`Left "Jobs") ~jobs:positions
  in
  let sections = [top] in
  wrap ~page_label:Links.(label jobs) ~fixed_footer:true sections

let testnet () =
  let comic ~title ~content ~alt_content ~img () =
    let image =
      match img with
      | `None -> None
      | `Placeholder -> Some (Image.placeholder 400 400)
      | `Custom elem -> Some elem
      | `Real s ->
          Some
            (Image.draw
               ~style:(Style.of_class "mw6-ns mw5 h5 hauto-ns w-100")
               ("/static/img/testnet/" ^ s)
               `Free)
    in
    let important_text =
      Important_text.create ~title:(`Left title) ~content ~alt_content ()
    in
    Compound_chunk.create ~variant:`No_image_on_small ~important_text ~image
      ~image_positioning:Image_positioning.Right ()
  in
  let top scheme =
    let open Html_concise in
    div []
      [ Section.carousel
          ~pages:
            [ comic ~title:"What is this?"
                ~content:(marked_up_content Copy.intro_slide)
                ~alt_content:None ~img:`None ()
            ; comic ~title:"Problem"
                ~content:(marked_up_content Copy.problem_slide)
                ~alt_content:(Some (marked_up_content Copy.alt_problem_slide))
                ~img:(`Real "problem.png") ()
            ; comic ~title:"Coda"
                ~content:(marked_up_content Copy.coda_slide_1)
                ~alt_content:
                  (Some (marked_up_content Copy.alt_coda_slide_1))
                  (*~img:(`Custom (div [Style.(render (of_class "flex"))]
            [ Image.draw ("/static/img/testnet/your-hands.png") (`Fixed (350, 400))
            ]))*)
                ~img:(`Real "your-hands.png") ()
            ; comic ~title:"Coda"
                ~content:(marked_up_content Copy.coda_slide_2)
                ~alt_content:None ~img:(`Real "net-hand.png") ()
            ; comic ~title:"Coda State Explorer"
                ~content:(marked_up_content Copy.conclusion)
                ~alt_content:(Some (marked_up_content Copy.alt_conclusion))
                ~img:`None () ]
          ~scheme () ]
  in
  let app scheme =
    let open Html_concise in
    Section.section' ~heading_size:`Large ~heading:"State Explorer"
      (div
         [ Style.(render (of_class "flex justify-center min-h7"))
         ; id "block-explorer" ]
         [])
      scheme
  in
  let sections = [top; app] in
  wrap
    ~headers:[Html.link ~href:"https://csshake.surge.sh/csshake.min.css"]
    ~fixed_footer:false
    ~page_label:Links.(label testnet)
    sections

let job_post name description =
  let content scheme =
    Section.major_text
      ~important_text:
        (Important_text.create ~title:(`Left name)
           ~content:(marked_up_content [description])
           ())
      ~scheme ()
  in
  wrap ~page_label:Links.(label jobs) [content]

let load_job_posts jobs =
  Deferred.List.map jobs ~f:(fun (name, file) ->
      let markdown = "jobs" ^/ file ^ ".markdown" in
      let%map description =
        Stationary.Html.to_string (Stationary.Html.load markdown)
      in
      let content = job_post name description in
      File.of_html ~name:(file ^ ".html") content )

let site () : Site.t Deferred.t =
  let open File_system in
  let%bind position_files = load_job_posts positions in
  let%map home = home () in
  Site.create
    ( List.map position_files ~f:file
    @ [ file (File.of_html ~name:"index.html" home)
      ; file (File.of_html ~name:"jobs.html" (jobs ()))
      ; file (File.of_html ~name:"testnet.html" (testnet ()))
      ; file (File.of_html ~name:"privacy.html" Privacy_policy.content)
      ; file (File.of_html ~name:"tos.html" Tos.content)
      ; file (File.of_path "static/favicon.ico")
      ; copy_directory "static" ] )

let main ~dst ~working_directory () =
  let%bind () = Sys.chdir working_directory in
  let%bind () =
    match%bind Sys.file_exists dst with
    | `Yes -> Process.run_expect_no_output_exn ~prog:"rm" ~args:["-r"; dst] ()
    | `No | `Unknown -> return ()
  in
  let%bind site = site () in
  Site.build ~dst site

let () =
  Command.async ~summary:"build site"
    (let open Command.Param in
    let open Command.Let_syntax in
    let%map dst = anon ("BUILD-DIR" %: file)
    and working_directory =
      flag "working-directory"
        ~doc:"Working directory relative to executing filesystem commands"
        (required string)
    in
    main ~dst ~working_directory)
  |> Command.run
