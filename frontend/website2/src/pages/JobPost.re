module Style = {
  open Css;
  let title = merge([Theme.H1.hero, style([color(Theme.Colors.saville)])]);

  let wrapper =
    style([
      padding2(~v=`rem(2.), ~h=`rem(2.)),
      media(
        Theme.MediaQuery.notMobile,
        [maxWidth(`rem(43.)), marginLeft(`auto), marginRight(`auto)],
      ),
    ]);

  let blogContent = BlogPost.Style.blogContent;
};

[@react.component]
let make = (~post: option(ContentType.JobPost.t)) => {
  switch (post) {
  | None =>
    <Page>
      <div> {React.string("Couldn't find that job post!")} </div>
      <Next.Link href="/careers">
        <a> {React.string("Check out the rest of our jobs instead")} </a>
      </Next.Link>
    </Page>
  | Some(({title, jobDescription: content}: ContentType.JobPost.t)) =>
    <Page>
      <div className=Style.wrapper>
        <div className=Style.title> {React.string(title)} </div>
        <Spacer height=2.0 />
        <div className=Style.blogContent>
          <Markdown content />
          <p>
            {React.string(
               "If you'd be interested in talking further, please get in touch by sending an email with your resume and the subject \""
               ++ title
               ++ " Applicant\" to ",
             )}
            <a
              href={
                "mailto:jobs@o1labs.org?subject=\"" ++ title ++ " Applicant\""
              }>
              {React.string("jobs@o1labs.org.")}
            </a>
          </p>
          <p>
            {React.string(
               "We are committed to building a diverse, inclusive company. People of color, LGBTQ individuals, women, and people with disabilities are strongly encouraged to apply.",
             )}
          </p>
        </div>
      </div>
    </Page>
  };
};

Next.injectGetInitialProps(make, ({Next.query}) => {
  switch (Js.Dict.get(query, "slug")) {
  | Some(slug) =>
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {
        "include": 0,
        "content_type": ContentType.JobPost.id,
        "fields.slug": slug,
      },
    )
    |> Js.Promise.then_((entries: ContentType.JobPost.entries) => {
         let post =
           switch (entries.items) {
           | [|item|] => Some(item.fields)
           | _ => None
           };
         Js.Promise.resolve({"post": post});
       })

  | None => Js.Promise.resolve({"post": None})
  }
});
