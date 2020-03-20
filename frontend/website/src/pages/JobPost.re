module Style = {
  open Css;
  let title = merge([Theme.H1.hero, style([color(Theme.Colors.saville)])]);

  let wrapper =
    style([
      padding2(~v=`rem(1.), ~h=`rem(1.)),
      media(
        Theme.MediaQuery.notMobile,
        [maxWidth(`rem(48.)), marginLeft(`auto), marginRight(`auto)],
      ),
    ]);

  let jobContent =
    style([
      position(`relative),
      selector("p", [fontSize(`rem(1.125)), lineHeight(`rem(1.875))]),
      selector(
        "h2",
        [
          Theme.Typeface.ibmplexsans,
          fontSize(`rem(1.68)),
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
      color(Theme.Colors.saville),
      Theme.Typeface.ibmplexsans,
      selector(
        "a",
        [
          fontSize(`rem(1.125)),
          lineHeight(`rem(1.875)),
          ...Theme.Link.basicStyles,
        ],
      ),
      selector(
        "ul",
        [
          paddingLeft(`rem(1.)),
          fontSize(`rem(1.125)),
          lineHeight(`rem(1.875)),
        ],
      ),
      selector("ul > li", [paddingLeft(`rem(0.5))]),
      selector("ul > li > ul", [marginLeft(`rem(1.))]),
    ]);
};

[@react.component]
let make = (~post: option(ContentType.JobPost.t)) => {
  switch (post) {
  | None =>
    <Page title="Work with us!">
      <div> {React.string("Couldn't find that job post!")} </div>
      <Next.Link href="/careers">
        <a> {React.string("Check out the rest of our jobs instead")} </a>
      </Next.Link>
    </Page>
  | Some(({title, jobDescription: content, slug}: ContentType.JobPost.t)) =>
    // Manually set the canonical route to remove .html
    <Page title route={"/jobs/" ++ slug}>
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <div className=Style.wrapper>
        <div className=Style.title> {React.string(title)} </div>
        <Spacer height=2.0 />
        <div className=Style.jobContent>
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
    let slug = ContentType.stripHTMLSuffix(slug);
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {
        "include": 0,
        "content_type": ContentType.JobPost.id,
        "fields.slug": slug,
      },
    )
    |> Promise.map((entries: ContentType.JobPost.entries) => {
         let post =
           switch (entries.items) {
           | [|item|] => Some(item.fields)
           | _ => None
           };
         {"post": post};
       });

  | None => Promise.return({"post": None})
  }
});
