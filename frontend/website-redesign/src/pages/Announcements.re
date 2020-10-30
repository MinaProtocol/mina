module Styles = {
  open Css;
  let titleSpacing = style([marginBottom(`rem(3.1875))]);
};

module MorePosts = {
  module Styles = {
    open Css;
    let postList =
      style([
        listStyleType(`none),
        width(`percent(100.)),
        height(`percent(100.)),
        display(`grid),
        gridColumnGap(`rem(2.)),
        gridRowGap(`rem(3.)),
        marginBottom(`rem(4.)),
        gridTemplateColumns([
          `repeat((`autoFit, `minmax((`minContent, `rem(23.5))))),
        ]),
        media(
          Theme.MediaQuery.desktop,
          [
            marginBottom(`rem(8.)),
            gridTemplateColumns([`repeat((`num(3), `fr(1.)))]),
          ],
        ),
      ]);

    let postItem = style([height(`percent(100.)), width(`percent(100.))]);
  };

  module Content = {
    [@react.component]
    let make = (~posts) => {
      <ul className=Styles.postList>
        {posts
         |> Array.map(item => {
              <li
                className=Styles.postItem
                key={item.ContentType.Announcement.title}>
                <ListModule.MainListing
                  item={ContentType.NormalizedPressBlog.ofAnnouncement(item)}
                  itemKind=ListModule.Announcement
                />
              </li>
            })
         |> React.array}
      </ul>;
    };
  };

  [@react.component]
  let make = (~posts) => {
    <div>
      <BlogModule.Title
        copy="More Blog posts"
        buttonCopy="See all posts"
        buttonHref={`Internal("/blog/all")}
      />
      <Content posts />
    </div>;
  };
};

[@react.component]
let make = (~posts) => {
  switch (Array.to_list(posts)) {
  | [] => failwith("Didn't load blog posts")
  | [featured, ...posts] =>
    <Page title="Mina Protocol Blog">
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <div className=Nav.Styles.spacer />
      <Hero
        title=""
        header=None
        copy=None
        background={
          Theme.desktop: "/static/img/MinaSpectrumPrimary3.jpg",
          Theme.tablet: "/static/img/MinaSpectrumPrimary3.jpg",
          Theme.mobile: "/static/img/MinaSpectrumPrimary3.jpg",
        }>
        <div className=Css.(style([marginTop(`rem(-12.))]))>
          <h5 className=Hero.Styles.headerLabel>
            {React.string("Announcements")}
          </h5>
          <Rule />
          <div className=Theme.Type.metadata>
            <span> {React.string("Announcement")} </span>
            <span> {React.string(" / ")} </span>
            <span>
              {React.string(featured.ContentType.Announcement.date)}
            </span>
          </div>
          <h1 className=Hero.Styles.header>
            {React.string(featured.ContentType.Announcement.title)}
          </h1>
          <p className=Hero.Styles.headerCopy>
            {React.string(featured.ContentType.Announcement.snippet)}
          </p>
        </div>
      </Hero>
      <Wrapped>
        <div className=Blog.Style.morePostsSpacing>
          <h2 className={Css.merge([Theme.Type.h2, Styles.titleSpacing])}>
            {React.string("More Announcement posts")}
          </h2>
        </div>
        <MorePosts.Content
          posts={Belt.Array.slice(Array.of_list(posts), ~offset=0, ~len=9)}
        />
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
    </Page>
  };
};

// TODO: pagination
Next.injectGetInitialProps(make, _ => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 0,
      "content_type": ContentType.Announcement.id,
      "order": "-fields.date",
    },
  )
  |> Promise.map((entries: ContentType.Announcement.entries) => {
       let posts =
         Array.map(
           (e: ContentType.Announcement.entry) => e.fields,
           entries.items,
         );
       {"posts": posts};
     })
});
