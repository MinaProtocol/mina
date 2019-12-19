module Style = {
  open Css;
  let title =
    style([
      color(Theme.Colors.saville),
      fontSize(`rem(3.)),
      letterSpacing(`rem(-0.01)),
      fontWeight(`bold),
      textDecoration(`none),
      Theme.Typeface.ibmplexsans,
    ]);

  let author = Blog.Style.author;
  let subtitle = Blog.Style.subtitle;
  let date = Blog.Style.date;

  let wrapper =
    style([
      padding2(~v=`rem(1.), ~h=`rem(1.)),
      media(
        Theme.MediaQuery.notMobile,
        [maxWidth(`rem(43.)), marginLeft(`auto), marginRight(`auto)],
      ),
    ]);

  let mediaMedium = media("screen and (min-width:30em)");
  let mediaLarge = media("screen and (min-width:60em)");

  let notLarge = selector(".not-large");
  let notMobile = selector(".not-mobile");
  let onlyLarge = selector(".large-only");
  let onlyMobile = selector(".mobile-only");

  let blogContent =
    style([
      position(`relative),
      selector("img", [width(`percent(100.))]),
      color(Theme.Colors.saville),
      Theme.Typeface.ibmplexsans,
      /* selector(".side-footnote-container", [height(`zero)]), */
      selector(".footnotes", [mediaLarge([display(`none)])]),
      selector("a", Theme.Link.basicStyles),
      selector("a.footnote-ref", [fontSize(`rem(0.5))]),
      selector(
        ".side-footnote",
        [
          position(`absolute),
          left(`percent(100.)),
          width(`rem(10.)),
          paddingLeft(`rem(1.)),
          marginTop(`rem(-0.5)),
          fontSize(`rem(0.75)),
          display(`none),
          mediaLarge([display(`block)]),
        ],
      ),
      // Visibility (based on screen width)
      notLarge([display(`block)]),
      onlyMobile([display(`block)]),
      notMobile([display(`none)]),
      onlyLarge([display(`none)]),
      mediaMedium([
        selector(".not-large, .not-mobile", [display(`block)]),
        selector(".mobile-only, .large-only", [display(`none)]),
      ]),
      mediaLarge([
        selector(".large-only, .not-mobile", [display(`block)]),
        selector(".mobile-only, .not-large", [display(`none)]),
      ]),
    ]);
};

[@react.component]
let make = (~post: option(ContentType.Post.t)) => {
  switch (post) {
  | None =>
    <Page>
      <div> {React.string("Couldn't find that blog post!")} </div>
      <Next.Link href="/blog">
        <a> {React.string("Check out the rest of our posts instead")} </a>
      </Next.Link>
    </Page>
  | Some(
      ({title, subtitle, author, date, text: content}: ContentType.Post.t),
    ) =>
    <Page>
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <div className=Style.wrapper>
        <div className=Style.title id="title"> {React.string(title)} </div>
        {ReactUtils.fromOpt(Js.Undefined.toOption(subtitle), ~f=s =>
           <div className=Style.subtitle id="subtitle">
             {React.string(s)}
           </div>
         )}
        <Spacer height=2.0 />
        <div className=Style.author id="author">
          {React.string("by " ++ author)}
        </div>
        <div className=Style.date id="date"> {React.string(date)} </div>
        <Spacer height=2.0 />
        <div className=Style.blogContent id="content">
          <Markdown content />
        </div>
      </div>
    </Page>
  };
};

let cache: Js.Dict.t(option(ContentType.Post.t)) = Js.Dict.empty();

Next.injectGetInitialProps(make, ({Next.query}) => {
  switch (Js.Dict.get(query, "slug")) {
  | Some(slug) =>
    switch (Js.Dict.get(cache, slug)) {
    | Some(post) => Js.Promise.resolve({"post": post})
    | None =>
      Contentful.getEntries(
        Lazy.force(Contentful.client),
        {
          "include": 0,
          "content_type": ContentType.Post.id,
          "fields.slug": slug,
        },
      )
      |> Js.Promise.then_((entries: ContentType.Post.entries) => {
           let post =
             switch (entries.items) {
             | [|item|] => Some(item.fields)
             | _ => None
             };
           Js.Dict.set(cache, slug, post);
           Js.Promise.resolve({"post": post});
         })
    }
  | None => Js.Promise.resolve({"post": None})
  }
});
