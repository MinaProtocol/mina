module Style = {
  open Css;
  let title =
    style([
      color(Theme.Colors.saville),
      fontSize(`rem(2.25)),
      letterSpacing(`rem(-0.0625)),
      fontWeight(`bold),
      textDecoration(`none),
      Theme.Typeface.ibmplexsans,
    ]);

  let subtitle =
    merge([Theme.Body.big, style([margin(`zero), fontWeight(`normal)])]);

  let postList =
    style([
      listStyleType(`none),
      maxWidth(`rem(43.)),
      marginLeft(`auto),
      marginRight(`auto),
    ]);

  let postListItem = style([marginBottom(`rem(2.))]);

  let date =
    style([
      Theme.Typeface.ibmplexsans,
      fontSize(`rem(0.75)),
      letterSpacing(`rem(0.3125)),
      fontWeight(`normal),
      color(Theme.Colors.slateAlpha(0.5)),
    ]);

  let author =
    style([
      Theme.Typeface.ibmplexsans,
      fontSize(`rem(0.75)),
      letterSpacing(`rem(0.3125)),
      fontWeight(`normal),
      color(Theme.Colors.slate),
      textTransform(`uppercase),
    ]);
};

[@react.component]
let make = (~posts) => {
  <Page>
    <Next.Head> Markdown.katexStylesheet </Next.Head>
    <ul className=Style.postList>
      {React.array(
         Array.map(
           (post: ContentType.Post.t) => {
             <li key={post.slug} className=Style.postListItem>
               <Next.Link
                 href="/blog/[slug]" _as={"/blog/" ++ post.slug} passHref=true>
                 <a className=Style.title> {React.string(post.title)} </a>
               </Next.Link>
               {ReactUtils.fromOpt(Js.Undefined.toOption(post.subtitle), ~f=s =>
                  <div className=Style.subtitle> {React.string(s)} </div>
                )}
               <Spacer height=1.5 />
               <div className=Style.author>
                 {React.string("by " ++ post.author)}
               </div>
               <div className=Style.date> {React.string(post.date)} </div>
             </li>
           },
           posts,
         ),
       )}
    </ul>
  </Page>;
};

// TODO: pagination
Next.injectGetInitialProps(make, _ => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {"include": 0, "content_type": ContentType.Post.id},
  )
  |> Js.Promise.then_((entries: ContentType.Post.entries) => {
       let posts =
         Array.map((e: ContentType.Post.entry) => e.fields, entries.items);
       Js.Promise.resolve({"posts": posts});
     })
});
