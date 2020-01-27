module Styles = {
  open Css;
  let page =
    style([display(`block), justifyContent(`center), overflowX(`hidden)]);
};

[@react.component]
let make = (~links) => {
  <Page title="Coda Cryptocurrency Protocol" footerColor=Theme.Colors.navyBlue>
    <div className=Styles.page>
      <section
        className=Css.(
          style([
            marginTop(`rem(-0.3125)),
            media(Theme.MediaQuery.full, [marginTop(`rem(-0.25))]),
          ])
        )>
        <Wrapped>
          <HeroSection />
          <CryptoAppsSection />
          <InclusiveSection />
          <SustainableSection />
          <GetInvolvedSection links />
        </Wrapped>
        <div
          className=Css.(
            style([
              backgroundColor(Theme.Colors.navyBlue),
              marginTop(`rem(13.)),
            ])
          )>
          <Wrapped> <TeamSection /> <InvestorsSection /> </Wrapped>
        </div>
      </section>
    </div>
  </Page>;
};

Next.injectGetInitialProps(make, _ => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {"include": 0, "sys.id": "15yfHjBude059Ak1YXgW9w"} // Entry ID of Knowledge Base file
  )
  |> Promise.map((entries: ContentType.KnowledgeBase.entries) => {
       let links = Array.map(
                     (e: ContentType.KnowledgeBase.entry) => e.fields.links,
                     entries.items,
                   )[0];
       {"links": links};
     })
});
