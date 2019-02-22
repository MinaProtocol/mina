open Core
open Async
open Stationary
open Common

let bigtext = Style.of_class "ocean f2-ns tracked-tightly"

let h2style = Style.(of_class "fw5 mt0 mb0 ml15 f2" + bigtext)

let linkstyle = Style.(of_class "dodgerblue fw5 no-underline hover-link")

module Title = struct
  open Html_concise

  let create copy =
    h1
      [ Style.just
          "fadedblue aktivgroteskex careers-double-line-header ttu f5 fw5 \
           tracked-more mb4" ]
      [text copy]
end

module Image_grid = struct
  open Html_concise

  let create images =
    (* On mobile a single hero (the first image) *)
    (* On desktop we grid display them *)
    let images = Non_empty_list.to_list images in
    let big_gallery =
      let row1_imgs, row2_imgs = List.split_n images 2 in
      let row1 = div [Style.just "careers-gallery-row1"] row1_imgs in
      let row2 = div [Style.just "careers-gallery-row2"] row2_imgs in
      div [] [row1; row2]
    in
    Mobile_switch.create ~not_small:big_gallery ~small:(List.hd_exn images)
end

module Tagline = struct
  open Html_concise

  let create copy =
    p [Style.(render (of_class "lh-copy f3" + bigtext))] [text copy]
end

module Qualities = struct
  open Html_concise

  module Quality = struct
    let create title reason =
      Mobile_switch.create
        ~not_small:
          (div
             [Style.just "flex justify-between mt45"]
             [ h2 [Style.(render (of_class "pr2" + h2style))] [text title]
             ; p [Style.just "w-65 mt0 mb0 lh-copy"] reason ])
        ~small:
          (div [Style.just "mt45"]
             [ h2 [Style.render h2style] [text title]
             ; p [Style.just "mt3 mb0 ml15 lh-copy"] reason ])
  end

  let create qualities =
    div [Style.just "mt45"]
      [ hr [Style.(render (of_class "mt45" + Styles.clean_hr))]
      ; div [Style.just "mt45"] qualities ]
end

module Benefits = struct
  open Html_concise

  module Benefit = struct
    let create category ?(top_style = "mt4") reasons =
      div
        [Style.just @@ "flex justify-between " ^ top_style]
        [ div
            [Style.just "flex justify-end w-30"]
            [h3 [Style.just "fw6 f5 ph4 mt0 mb0"] [text category]]
        ; ul
            [Style.just "mt0 mb0 ph0 w-70"]
            (List.map reasons ~f:(fun r ->
                 li [Style.just "lh-copy list mb0 mt0"] r )) ]
  end

  let create benefits =
    div []
      [ hr [Style.(render (of_class "mt45" + Styles.clean_hr))]
      ; Mobile_switch.create
          ~not_small:
            (div
               [Style.just "flex justify-between mt45"]
               [ h2 [Style.(render h2style)] [text "Benefits"]
               ; div [Style.just "w-70 mt3"] benefits ])
          ~small:
            (div [Style.just "mt45"]
               [ h2 [Style.(render h2style)] [text "Benefits"]
               ; div [Style.just "mt4 ml15 mt3"] benefits ]) ]
end

module Apply = struct
  open Html_concise

  module Role = struct
    let create name link =
      a
        [href link; Style.(render (of_class "f5" + linkstyle))]
        [text (name ^ " (San Francisco).")]
  end

  let create roles =
    let apply = h2 [Style.render h2style] [text "Apply"] in
    let roles_content =
      List.map roles ~f:(fun r -> li [Style.just "list lh-copy"] [r])
    in
    div []
      [ hr [Style.(render (of_class "mt45" + Styles.clean_hr))]
      ; Mobile_switch.create
          ~not_small:
            (div
               [Style.just "flex justify-between mt45"]
               [ div [Style.just "w-50"] [apply]
               ; div [Style.just "w-50"]
                   [ul [Style.just "mt0 mb0 ph0"] roles_content] ])
          ~small:
            (div [Style.just "mt45"]
               [apply; ul [Style.just "mt4 ml15 mb0 ph0"] roles_content]) ]
end

let content =
  let open Html_concise in
  let content =
    div
      [Style.just "mw960 pv3 center ph3 ibmplex oceanblack"]
      [ Title.create "Work with us!"
      ; Image_grid.create
          (Non_empty_list.init
             (Image.draw "/static/img/careers/group-outside.jpg" `Free)
             [ Image.draw "/static/img/careers/group-in-house.jpg" `Free
             ; Image.draw "/static/img/careers/nacera-outside.jpg" `Free
             ; Image.draw "/static/img/careers/john-cooking.jpg" `Free
             ; Image.draw "/static/img/careers/vanishree-talking.jpg" `Free ])
      ; div
          [Style.just "mw800 center"]
          [ Tagline.create
              "We’re using cryptography and cryptocurrency to build \
               computing systems that put people back in control of their \
               digital&nbsp;lives."
          ; Qualities.(
              create
                [ Quality.create "Open Source"
                    [ text
                        "We passionately believe in the open-source \
                         philosophy, and make our software free for the \
                         entire world to&nbsp;use."
                    ; a
                        [href "/static/code.html"; Style.render linkstyle]
                        [text "Take&nbsp;a&nbsp;look&nbsp;→"] ]
                ; Quality.create "Collaboration"
                    [ text
                        "The problems we face are novel and challenging and \
                         we take them on as a&nbsp;team." ]
                ; Quality.create "Inclusion"
                    [ text
                        "We’re working on technologies with the potential \
                         to reimagine social structures. We believe it’s \
                         important to incorporate diverse perspectives from \
                         conception through&nbsp;realization." ] ])
          ; Benefits.(
              create
                [ Benefit.create "Healthcare" ~top_style:""
                    [ [ text
                          "We cover 100% of employee premiums for platinum \
                           healthcare plans with zero deductible, and 99% of \
                           vision and dental&nbsp;premiums" ] ]
                ; Benefit.create "401k"
                    [ [ text
                          "401k contribution matching up to 3% of&nbsp;salary"
                      ] ]
                ; Benefit.create "Education"
                    [ [ text
                          "$750 annual budget for conferences of your choice \
                           (we cover company-related&nbsp;conferences)" ]
                    ; [text "Office library"]
                    ; [text "Twice-a-week learning lunches"] ]
                ; Benefit.create "Equipment"
                    [ [ text
                          "Top-of-the-line laptop, $500 monitor budget and \
                           $500 peripheral budget" ] ]
                ; Benefit.create "Time&nbsp;off"
                    [ [ text
                          "Unlimited vacation, with encouragement for \
                           employees to take off"
                      ; span [Style.just "i"] [text "at least"]
                      ; text "14 days&nbsp;annually" ] ]
                ; Benefit.create "Meals"
                    [[text "Healthy snacks and provided lunch twice a week"]]
                ; Benefit.create "Other"
                    [ [text "Parental leave"]
                    ; [text "Commuting benefits"]
                    ; [text "Bike-friendly culture"]
                    ; [text "Take up to 1 day of PTO per year to volunteer"]
                    ; [text "We match nonprofit donations up to $500 per year"]
                    ; [text "...and many others!"] ] ])
          ; Apply.(
              create
                [ Role.create "Engineering Manager" "/jobs/product-manager.html"
                ; Role.create "Product Manager"
                    "/jobs/engineering-manager.html"
                ; Role.create "Senior Frontend Engineer"
                    "/jobs/senior-frontend-engineer.html"
                ; Role.create "Protocol Reliability Engineer"
                    "/jobs/protocol-reliability-engineer.html"
                ; Role.create "Senior Protocol Engineer"
                    "/jobs/protocol-engineer.html" ]) ] ]
  in
  wrap_simple
    ~body_style:(Style.of_class "bg-white")
    ~navbar:(Navbar.navbar "careers") ~page_label:"careers"
    ~show_newsletter:false ~append_footer:true content
    ~headers:
      [ Html.link ~href:"/static/css/careers.css"
      ; Html.link ~href:"https://use.typekit.net/mta7mwm.css" ]
