open Core
open Async
open Stationary

let wrap =
  let open Html in
  let navbar =
    let page title url =
      node "li" []
        [ node "a" [ Attribute.href url ] [ text title ] ]
    in
    node "div" [ Attribute.class_ "navbar-collapse" ]
      [ node "ul" [ Attribute.class_ "nav navbar-nav" ]
          [ page "Home" "index.html"
          ; page "About" "about.html"
          ]
      ]
  in
  let footer =
    node "div"
      [ Attribute.class_ "camel"
      ]
      [ node "img"
          [ Attribute.src "https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/07._Camel_Profile%2C_near_Silverton%2C_NSW%2C_07.07.2007.jpg/487px-07._Camel_Profile%2C_near_Silverton%2C_NSW%2C_07.07.2007.jpg"
          ]
          []
      ; node "p" []
          [ node "i" [] [text "This is a camel."]
          ]
      ]
  in
  fun content ->
    node "html" []
      [ node "head" []
          [ link ~href:"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css"
          ; link ~href:"assets/main.css"
          ; node "script"
              [ Attribute.create "type" "text/javascript"
              ; Attribute.src "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js"
              ]
              []
          ]
      ; node "body" []
          [ node "h1" []
              [ text "Stationary example blog" ]
          ; navbar
          ; hr []
          ; node "div" [ Attribute.class_ "container" ] [ content ]
          ; hr []
          ; footer
          ]
      ]

let posts () =
  Sys.ls_dir "posts" >>= fun post_paths ->
  Deferred.List.map post_paths ~f:(fun path ->
    Reader.load_sexp_exn ("posts" ^/ path) Post.t_of_sexp
  )
  >>| fun posts ->
  List.sort ~cmp:(fun p1 p2 -> - Date.compare p1.Post.date p2.date) posts

let about () =
  Reader.file_contents "about.txt" >>| fun about_txt ->
  wrap (Html.text about_txt)

let main () =
  about () >>= fun about ->
  posts () >>= fun posts ->
  let home =
    let open Html in
    wrap (
      node "div" []
        [ node "h1" [] [ text "Here is the most recent post" ]
        ; node "div"
            [ Attribute.class_ "most-recent-post" ]
            [ Post.to_html (List.hd_exn posts) ]
        ; node "h2" [] [ text "Here are all the posts" ]
        ; node "ul" []
            (List.map posts ~f:(fun p ->
              node "li" []
                [ node "a" [ Attribute.href ("posts" ^/ Post.filename p) ]
                    [ text p.title ]
                ]))
        ]
    )
  in
  let site =
    let open File_system in
    Site.create
      [ file (File.of_html ~name:"index.html" home)
      ; file (File.of_html ~name:"about.html" about)
      ; copy_directory "assets"
      ; directory "posts"
          (List.map posts ~f:(fun p ->
            file (
              File.of_html
                ~name:(Post.filename p) (wrap (Post.to_html p)))))
      ]
  in
  Sys.file_exists "_site" >>= function
  | `No -> Site.build site ~dst:"_site"
  | `Yes | `Unknown ->
    print_endline "Please remove _site before building";
    return ()

let () =
  Command.run (
    Command.async ~summary:"Build the example blog in the directory _site"
      Command.Spec.empty
      main
  )
