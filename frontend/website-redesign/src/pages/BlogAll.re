module Styles = {
  open Css;
  let titleSpacing = style([marginBottom(`rem(3.1875))]);
};

[@react.component]
let make = (~posts) => {
  <Page title="Mina Protocol Blog">
    <Next.Head> Markdown.katexStylesheet </Next.Head>
    <div className=Nav.Styles.spacer />
    <Wrapped>
      <div className=Blog.Style.morePostsSpacing>
        <h2 className={Css.merge([Theme.Type.h2, Styles.titleSpacing])}>
          {React.string("All Blog Posts")}
        </h2>
        <Blog.MorePosts.Content posts />
      </div>
    </Wrapped>
    <ButtonBar
      kind=ButtonBar.CommunityLanding
      backgroundImg="/static/img/ButtonBarBackground.jpg"
    />
    <Blog.InternalCtaSection
      backgroundImg={
        Theme.desktop: "/static/img/MinaSpectrumBackground.jpg",
        Theme.tablet: "/static/img/MinaSpectrumBackground.jpg",
        Theme.mobile: "/static/img/MinaSpectrumBackground.jpg",
      }
    />
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
