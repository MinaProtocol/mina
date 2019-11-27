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
    style([maxWidth(`rem(43.)), marginLeft(`auto), marginRight(`auto)]);

  let blogContent =
    style([
      selector("img", [width(`percent(100.))]),
      color(Theme.Colors.saville),
      Theme.Typeface.ibmplexsans,
      selector(
        ".side-footnote",
        [
          position(`absolute),
          left(`percent(100.)),
          width(`rem(10.)),
          paddingLeft(`rem(1.)),
          marginTop(`rem(-0.5)),
          fontSize(`rem(0.75)),
        ],
      ),
    ]);
};

[@react.component]
let make = (~post: option(ContentType.post)) => {
  switch (post) {
  | None =>
    <Page>
      <div> {React.string("Couldn't find that blog post!")} </div>
      <Next.Link href="/blog">
        <a> {React.string("Check out the rest of our posts instead")} </a>
      </Next.Link>
    </Page>
  | Some({ContentType.title, subtitle, author, date, text: content}) =>
    <Page>
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <div className=Style.wrapper>
        <div className=Style.title> {React.string(title)} </div>
        {Util.reactMap(Js.Undefined.toOption(subtitle), ~f=s =>
           <div className=Style.subtitle> {React.string(s)} </div>
         )}
        <Spacer height={`rem(2.0)} />
        <div className=Style.author> {React.string("by " ++ author)} </div>
        <div className=Style.date> {React.string(date)} </div>
        <Spacer height={`rem(2.0)} />
        <span className=Style.blogContent> <Markdown content /> </span>
      </div>
    </Page>
  };
};

let postCache: Js.Dict.t(option(ContentType.post)) = Js.Dict.empty();

Next.injectGetInitialProps(make, ({Next.query}) => {
  switch (Js.Dict.get(query, "slug")) {
  | Some(slug) =>
    Contentful.get(
      ~cache=postCache,
      ~key=slug,
      ~query={
        "include": 0,
        "content_type": ContentType.post,
        "fields.slug": slug,
      },
      ~fn=p =>
      {"post": p}
    )
  | None => Js.Promise.resolve({"post": None})
  }
});
