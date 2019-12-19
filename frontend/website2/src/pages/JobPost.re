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
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <div className=Style.wrapper>
        <div className=Style.title> {React.string(title)} </div>
        <Spacer height=2.0 />
        <div className=Style.blogContent>
          <Markdown content />
          <Spacer height=1.0 />
          <h2> {React.string("About Us")} </h2>
          <p>
            {React.string(
               "O(1) Labs is aiming to develop the first cryptocurrency protocol that can deliver on the promise of supporting real-world applications and widespread use. Our team is based in San Francisco, and we are funded by top investors (including Polychain, Metastable, Max Levchin, and Naval Ravikant).",
             )}
          </p>
          <p>
            {React.string(
               "We're bringing Coda Protocol to market, a cryptocurrency that compresses the blockchain from hundreds of gigabytes down to the size of a few tweets. It can scale to thousands of transactions per second and millions of users while remaining decentralized enough for cellphones to be fully verifying nodes.",
             )}
          </p>
          <p>
            {React.string(
               "We're working on technologies with the potential to reimagine social structures. We believe it's important to incorporate diverse perspectives from conception through realization.",
             )}
          </p>
          <p>
            {React.string(
               "This is a chance to join a small, collaborative team and have a ton of independence while working on fascinating cross-disciplinary problems that span cryptography, engineering, product design, economics, and sociology. We also offer competitive compensation both in salary and equity as well as top-of-the-market benefits.",
             )}
          </p>
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
