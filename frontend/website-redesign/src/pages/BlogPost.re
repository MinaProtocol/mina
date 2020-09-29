module Style = {
  open Css;

  let author = Blog.Style.author;
  let subtitle = Blog.Style.subtitle;
  let date = Blog.Style.date;

  let marginX = x => [marginLeft(x), marginRight(x)];
  let basicContainer =
    style(
      marginX(`rem(1.25))
      @ [
        marginTop(`rem(4.2)),
        marginBottom(`rem(1.9)),
        media(
          Theme.MediaQuery.tablet,
          [
            marginBottom(`rem(6.5)),
            marginTop(`rem(7.)),
            ...marginX(`rem(2.5)),
          ],
        ),
        media(
          Theme.MediaQuery.desktop,
          [
            marginBottom(`rem(8.)),
            marginTop(`rem(7.)),
            ...marginX(`rem(9.5)),
          ],
        ),
      ],
    );

  let mediaMedium = media("screen and (min-width:30em)");
  let mediaLarge = media("screen and (min-width:60em)");

  let notLarge = selector(".not-large");
  let notMobile = selector(".not-mobile");
  let onlyLarge = selector(".large-only");
  let onlyMobile = selector(".mobile-only");

  let blogContent =
    style([
      position(`relative),
      /* selector(".side-footnote-container", [height(`zero)]), */
      selector(".footnotes", [mediaLarge([display(`none)])]),
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

  let container = merge([basicContainer, blogContent]);
};

[@react.component]
let make = (~post: option(ContentType.BlogPost.t)) => {
  switch (post) {
  | None =>
    <Page title="Mina Protocol Blog">
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
      <Hero
        metadata={
          Some(
            CategoryDateSourceText.{category: "Post", date, source: author},
          )
        }
        title="Blog"
        header=title
        copy={Js.Undefined.toOption(subtitle)}
        background=Theme.{
          desktop: "/static/img/BlogDetailImage.png",
          tablet: "/static/img/BlogDetailImage.png",
          mobile: "/static/img/BlogDetailImage.png",
          // TODO: Get non-desktop versions of this image
        }
      />
      <div className=Style.container> <Markdown content /> </div>
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
