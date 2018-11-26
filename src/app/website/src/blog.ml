open Core
open Async
open Config
open Stationary
open Common

let post_url (post : Post.t) = blog_base ^/ "posts" ^/ post.basename ^ ".html"

let comments_section post =
  sprintf
    {literal|
    <div id="disqus_thread"></div>
<script>

var disqus_config = function () {
this.page.url = "%s";  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = "%s"; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};
(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = 'https://o1labs.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
<noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>|literal}
    (String.escaped (web_base ^/ post_url post))
    (String.escaped post.basename)
  |> Html.literal

let call_to_action_footer =
  let open Html_concise in
  let id_str = "call-to-action-footer" in
  div
    [class_ "call-to-action-footer"; id id_str]
    [ div []
        [ h1 [class_ "mailing-list-header"] [text "Join our mailing list"]
        ; Html.literal
            {literal|
          <form class='flex' method='POST' action='https://formspree.io/mailing-list@o1labs.org'>
            <input class='email' name='email' type='email' placeholder='hi@example.com'>
            <button type='submit' class='sign-up'>SIGN UP</button>
          </form>|literal}
        ; node "a"
            [href "https://twitter.com/o1_labs"; class_ "twitter-link"]
            [node "img" [Attribute.src "/static/img/twitter.svg"] []]
        ; node "div"
            [ class_ "close-call-to-action"
            ; Attribute.create "onclick"
                (sprintf {js|document.getElementById('%s').remove()|js}
                   (String.escaped id_str)) ]
            [node "img" [Attribute.src "/static/img/x.svg"] []] ] ]

let blog_footer = Html_concise.(div [class_ "blog-footer"] [])

let wrap_post ~standalone (post : Post.t) =
  let url = post_url post in
  let open Html_concise in
  div [class_ "post-container"]
    ( [ h1 [class_ "post-title"] [a [href url] [text post.title]]
      ; div [class_ "info"]
          [text (sprintf "Posted on %s" (Date.format post.date "%B %e, %Y"))]
      ; post.content
      ; call_to_action_footer ]
    @
    if standalone then [comments_section post; blog_footer]
    else [div [class_ "post-separator"] []] )

let load_posts () =
  let assert_no_duplicate_titles (posts : Post.t list) =
    let has_dup =
      List.contains_dup
        ~compare:(fun p1 p2 -> String.compare p1.Post.basename p2.basename)
        posts
    in
    if has_dup then failwith "Duplicate title in posts"
  in
  let%bind post_paths =
    Sys.ls_dir posts_dir
    >>| List.filter ~f:(fun p ->
            let _, e = Filename.split_extension p in
            e = Some "markdown" )
  in
  let%map posts =
    Deferred.List.map post_paths ~f:(fun p -> Post.load (posts_dir ^/ p))
  in
  let posts =
    List.sort ~cmp:(fun p1 p2 -> Date.compare p2.Post.date p1.date) posts
  in
  assert_no_duplicate_titles posts ;
  posts

let headers =
  let open Html in
  let open Attribute in
  let mathjax_url =
    "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.2/MathJax.js?config=TeX-MML-AM_CHTML"
  in
  [ link ~href:"/static/css/code.css"
  ; link ~href:"/static/css/blog-common.css"
  ; literal
      {html|<link media='only screen and (min-device-width: 700px)' rel='stylesheet' href='/static/css/blog.css'>|html}
  ; literal
      {html|<link media='only screen and (max-device-width: 700px)' rel='stylesheet' href='/static/css/blog-mobile.css'>|html}
  ; node "script" [src mathjax_url] [] ]

let wrap ?title cs = wrap ?title ~headers cs

let index (posts : Post.t list) =
  let open Html_concise in
  wrap ~title:"Blog"
    [ Fn.const
        (div [class_ "posts"]
           (List.map posts ~f:(fun p -> wrap_post ~standalone:false p))) ]

let load () =
  let open File_system in
  let%map posts = load_posts () in
  let posts_dir =
    directory "posts"
      (List.map posts ~f:(fun p ->
           file
             (File.of_html ~name:(p.basename ^ ".html")
                (wrap ~title:p.title [Fn.const (wrap_post ~standalone:true p)]))
       ))
  in
  directory "blog"
    [file (File.of_html ~name:"index.html" (index posts)); posts_dir]
