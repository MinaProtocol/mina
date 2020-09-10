module Style = {
  open Css;
  let title =
    style([
      color(black),
      fontSize(`rem(2.25)),
      letterSpacing(`rem(-0.0625)),
      fontWeight(`semiBold),
      textDecoration(`none),
      Theme.Typeface.ibmplexsans,
      media(Theme.MediaQuery.notMobile, [fontSize(`rem(3.))]),
      hover([color(black)]),
    ]);

  let subtitle =
    merge([
      Theme.Type.sectionSubhead,
      style([margin(`zero), fontWeight(`normal)]),
    ]);

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
      letterSpacing(`rem(0.0875)),
      fontWeight(`normal),
      color(Theme.Colors.black),
    ]);

  let author =
    style([
      Theme.Typeface.ibmplexsans,
      fontSize(`rem(0.75)),
      letterSpacing(`rem(0.0875)),
      fontWeight(`normal),
      color(Theme.Colors.black),
      textTransform(`uppercase),
    ]);
};

[@react.component]
let make = (~posts) => {
  <Page title="Coda Protocol Blog">
    <Next.Head> Markdown.katexStylesheet </Next.Head>
    <ul className=Style.postList>
      {React.array(
         Array.map(
           (post: ContentType.BlogPost.t) => {
             <li key={post.slug} className=Style.postListItem>
               <Next.Link
                 href="/blog/[slug]" _as={"/blog/" ++ post.slug} passHref=true>
                 <a className=Style.title> {React.string(post.title)} </a>
               </Next.Link>
               {ReactExt.fromOpt(Js.Undefined.toOption(post.subtitle), ~f=s =>
                  <div className=Style.subtitle> {React.string(s)} </div>
                )}
               <Spacer height=1. />
               <div className=Style.author>
                 {React.string("by " ++ post.author)}
               </div>
               <div className=Style.date> {React.string(post.date)} </div>
               <Spacer height=1.5 />
               <div className=Theme.Type.paragraph>
                 {React.string(post.snippet)}
               </div>
               <Spacer height=1. />
               <Next.Link
                 href="/blog/[slug]" _as={"/blog/" ++ post.slug} passHref=true>
                 <a className=Theme.Type.paragraph>
                   {React.string({js|Read more →|js})}
                 </a>
               </Next.Link>
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
    {
      "include": 0,
      "content_type": ContentType.BlogPost.id,
      "order": "-fields.date",
    },
  )
  |> Promise.map((entries: ContentType.BlogPost.entries) => {
       let posts =
         Array.map(
           (e: ContentType.BlogPost.entry) => e.fields,
           entries.items,
         );
       {"posts": posts};
     })
});
