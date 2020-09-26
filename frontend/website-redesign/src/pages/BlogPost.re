module Style = {
  open Css;

  let author = Blog.Style.author;
  let subtitle = Blog.Style.subtitle;
  let date = Blog.Style.date;

  let marginX = x => [marginLeft(x), marginRight(x)];
  let container = style(marginX(`rem(1.25)) @ [
      marginTop(`rem(4.2)),
      marginBottom(`rem(1.9)),
      media(
        Theme.MediaQuery.tablet,
        [ marginBottom(`rem(6.5)),
          marginTop(`rem(7.)),
         ...marginX(`rem(2.5)),
        ]
      ),
      media(
        Theme.MediaQuery.desktop,
        [ marginBottom(`rem(8.)),
          marginTop(`rem(7.)),
          ...marginX(`rem(9.5))
        ]
      ),
  ]);
};

[@react.component]
let make = (~post: option(ContentType.BlogPost.t)) => {
  switch (post) {
  | None =>
    <Page title="Coda Protocol Blog">
      <div> {React.string("Couldn't find that blog post!")} </div>
      <Next.Link href="/blog">
        <a> {React.string("Check out the rest of our posts instead")} </a>
      </Next.Link>
    </Page>
  | Some(
      (
        {title, subtitle, author, date, text: content, snippet, slug}: ContentType.BlogPost.t
      ),
    ) =>
    // Manually set the canonical route to remove .html
    <Page title description=snippet route={"/blog/" ++ slug}>
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <Hero metadata=Some(CategoryDateSourceText.{ category: "Post", date, source: author }) title="Blog" header=title copy=Js.Undefined.toOption(subtitle) background=Theme.{
        desktop: "/static/img/BlogDetailImage.png",
        tablet: "/static/img/BlogDetailImage.png",
        mobile: "/static/img/BlogDetailImage.png"
          // TODO: Get non-desktop versions of this image
      }  />
      <div className=Style.container>
        <Markdown content />
      </div>
    </Page>
  };
};

let cache: Js.Dict.t(option(ContentType.BlogPost.t)) = Js.Dict.empty();

Next.injectGetInitialProps(make, ({Next.query}) => {
  switch (Js.Dict.get(query, "slug")) {
  | Some(slug) =>
    let slug = ContentType.stripHTMLSuffix(slug);
    switch (Js.Dict.get(cache, slug)) {
    | Some(post) => Js.Promise.resolve({"post": post})
    | None =>
      Contentful.getEntries(
        Lazy.force(Contentful.client),
        {
          "include": 0,
          "content_type": ContentType.BlogPost.id,
          "fields.slug": slug,
        },
      )
      |> Promise.map((entries: ContentType.BlogPost.entries) => {
           let post =
             switch (entries.items) {
             | [|item|] => Some(item.fields)
             | _ => None
             };
           Js.Dict.set(cache, slug, post);
           {"post": post};
         })
    };
  | None => Js.Promise.resolve({"post": None})
  }
});
