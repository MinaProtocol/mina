module Style = {
  open Css;
  let title =
    style([
      color(Theme.Colors.black),
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
        [maxWidth(`rem(48.)), marginLeft(`auto), marginRight(`auto)],
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
      selector("p", [lineHeight(`abs(1.5))]),
      selector(
        "h2",
        [
          Theme.Typeface.monumentGrotesk,
          fontSize(`rem(1.125)),
          letterSpacing(`em(0.1666)),
          textTransform(`uppercase),
          marginBottom(`rem(1.75)),
          marginTop(`rem(1.75)),
          lineHeight(`abs(1.25)),
        ],
      ),
      selector("img", [width(`percent(100.))]),
      selector(
        "hr",
        [
          backgroundImage(
            linearGradient(
              `deg(90.),
              [
                (`percent(25.), `rgb((27, 104, 191))),
                (`percent(0.), `rgba((255, 255, 255, 0.))),
              ],
            ),
          ),
          backgroundSize(`size((`rem(0.25), `rem(0.125)))),
          backgroundRepeat(`repeatX),
          width(`percent(100.)),
          height(`rem(0.125)),
          border(`zero, `none, white),
          marginTop(`rem(2.)),
          marginBottom(`rem(2.)),
        ],
      ),
      color(Theme.Colors.black),
      Theme.Typeface.ibmplexsans,
      /* selector(".side-footnote-container", [height(`zero)]), */
      selector(".footnotes", [mediaLarge([display(`none)])]),
      selector("a", []),
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
      selector("ul", [paddingLeft(`rem(1.))]),
      selector("ul > li", [paddingLeft(`rem(0.5))]),
      selector("ul > li > ul", [marginLeft(`rem(1.))]),
      selector(
        "img + em",
        [
          fontSize(`px(13)),
          color(`hex("757575")),
          width(`percent(100.)),
          display(`inlineBlock),
          textAlign(`center),
        ],
      ),
      mediaMedium([
        selector(".not-large, .not-mobile", [display(`block)]),
        selector(".mobile-only, .large-only", [display(`none)]),
        selector("ul", [marginLeft(`rem(-1.0)), paddingLeft(`rem(0.))]),
        selector("ul > li", [paddingLeft(`rem(1.0))]),
        selector("ul > li > ul", [marginLeft(`rem(1.))]),
      ]),
      mediaLarge([
        selector(".large-only, .not-mobile", [display(`block)]),
        selector(".mobile-only, .not-large", [display(`none)]),
      ]),
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
      <div className=Style.wrapper>
        <div className=Style.title id="title"> {React.string(title)} </div>
        {ReactExt.fromOpt(Js.Undefined.toOption(subtitle), ~f=s =>
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
