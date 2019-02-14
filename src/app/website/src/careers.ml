open Core
open Async
open Stationary
open Common

let bigtext = Style.of_class "ocean f2 tracked-tightly"

let h2style = Style.(of_class "fw5" + bigtext)

module Title = struct
  open Html_concise

  let create copy = h1 [] [text copy]
end

module Image_grid = struct
  open Html_concise

  let create images =
    (* On mobile a single hero (the first image) *)
    (* On desktop we grid display them *)
    Mobile_switch.create
      ~not_small:(div [] (Non_empty_list.to_list images))
      ~small:(Non_empty_list.head images)
end

module Tagline = struct
  open Html_concise

  let create copy =
    p [Style.(render (of_class "lh-copy" + bigtext))] [text copy]
end

module Qualities = struct
  open Html_concise

  module Quality = struct
    let create title reason =
      div []
        [ h2 [Style.(render h2style)] [text title]
        ; p [Style.just "lh-copy"] [text reason] ]
  end

  let create qualities = div [] (hr [Style.render Styles.clean_hr] :: qualities)
end

module Benefits = struct
  open Html_concise

  module Benefit = struct
    let create category reasons =
      div []
        [ h3 [] [text category]
        ; ul []
            (List.map reasons ~f:(fun r ->
                 li [Style.just "lh-copy list"] [text r] )) ]
  end

  let create benefits =
    div []
      [ hr [Style.render Styles.clean_hr]
      ; h2 [Style.render h2style] [text "Benefits"]
      ; div [] benefits ]
end

module Apply = struct
  open Html_concise

  module Role = struct
    let create name link = a [href link] [text (name ^ " (San Francisco).")]
  end

  let create roles =
    div []
      [ h2 [Style.render h2style] [text "Apply"]
      ; ul [] (List.map roles ~f:(fun r -> li [Style.just "list"] [r])) ]
end

let content =
  let open Html_concise in
  let content =
    div
      [Style.just "mw960 pv3 center ph3 ibmplex oceanblack"]
      [ Title.create "Work with us!"
      ; Image_grid.create
          (Non_empty_list.init
             (Image.draw "/static/img/cohn.jpg" `Free)
             [ Image.draw "/static/img/cohn.jpg" `Free
             ; Image.draw "/static/img/cohn.jpg" `Free
             ; Image.draw "/static/img/cohn.jpg" `Free
             ; Image.draw "/static/img/cohn.jpg" `Free ])
      ; div
          [Style.just "mw800 center"]
          [ Tagline.create
              "We’re using cryptography and cryptocurrency to build \
               computing systems that put people back in control of their \
               digital lives."
          ; Qualities.(
              create
                [ Quality.create "Open Source"
                    "We passionately believe in the open-source philosophy, \
                     and make our software free for the entire world to use.  \
                     Take a look  →"
                ; Quality.create "Collaboration"
                    "The problems we face are novel and challenging, so we \
                     take them on as a team."
                ; Quality.create "Inclusion"
                    "We’re working on technologies with the potential to \
                     reimagine social structures. We believe it’s important \
                     to incorporate diverse perspectives from conception \
                     through realization." ])
          ; Benefits.(
              create
                [ Benefit.create "Healthcare"
                    [ "We cover 100% of employee premiums for platinum \
                       healthcare plans with zero deductible, and 99% of \
                       vision and dental premiums" ]
                ; Benefit.create "401k"
                    ["Matching 401k contributions up to 3% of salary"]
                ; Benefit.create "Education"
                    [ "$750 annual budget for conferences of your choice (we \
                       cover company-related conferences)"
                    ; "Office library"
                    ; "Twice-a-week learning lunches" ]
                ; Benefit.create "Equipment"
                    [ "Top-of-the-line laptop + $500 monitor budget + $500 \
                       peripheral budget" ]
                ; Benefit.create "Time off"
                    [ "Unlimited vacation, with encouragement for employees \
                       to take off at least 14 days annually" ]
                ; Benefit.create "Meals"
                    ["Healthy snacks and provided lunch twice a week"]
                ; Benefit.create "Other"
                    [ "Parental leave"
                    ; "Commuting benefits"
                    ; "Bike-friendly culture"
                    ; "Take up to 1 day (8 hours) of paid time off per year \
                       to volunteer for the causes closest to your heart"
                    ; "We match nonprofit donations up to $500 per year"
                    ; "...and many others!" ] ])
          ; Apply.(
              create
                [ Role.create "Engineering Manager" "/jobs/product-manager.html"
                ; Role.create "Product Manager"
                    "/jobs/engineering-manager.html"
                ; Role.create "Senior Frontend Engineer"
                    "/jobs/frontend-engineer.html"
                ; Role.create "Protocol Reliability Engineer"
                    "/jobs/protocol-reliability-engineer.html"
                ; Role.create "Developer Advocate"
                    "/jobs/developer-advocate.html" ]) ] ]
  in
  wrap_simple
    ~body_style:(Style.of_class "bg-white")
    ~navbar:(Navbar.navbar "careers") ~page_label:"careers"
    ~show_newsletter:false ~append_footer:true content
