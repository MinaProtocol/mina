module Style = {
  open Css;
  let title =
    style([
      color(black),
      fontSize(`rem(2.25)),
      letterSpacing(`rem(-0.0625)),
      fontWeight(`semiBold),
      textDecoration(`none),
      Theme.Typeface.ibmplexsans,
      media(Theme.MediaQuery.notMobile, [fontSize(`rem(3.))]),
      hover([color(black)]),
    ]);

  let subtitle =
    merge([
      Theme.Type.sectionSubhead,
      style([margin(`zero), fontWeight(`normal)]),
    ]);

  let date =
    style([
      Theme.Typeface.ibmplexsans,
      fontSize(`rem(0.75)),
      letterSpacing(`rem(0.0875)),
      fontWeight(`normal),
      color(Theme.Colors.black),
    ]);

  let author =
    style([
      Theme.Typeface.ibmplexsans,
      fontSize(`rem(0.75)),
      letterSpacing(`rem(0.0875)),
      fontWeight(`normal),
      color(Theme.Colors.black),
      textTransform(`uppercase),
    ]);

  let container = style([maxWidth(`rem(71.))]);

  let morePostsSpacing = style([marginTop(`rem(7.1875))]);

  let marginX = x => [marginLeft(x), marginRight(x)];
  let _eyebrowSpacing =
    style(
      marginX(`rem(1.25))
      @ [
        maxWidth(`rem(71.)),
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
};

module MorePosts = {
  module Styles = {
    open Css;
    let postList =
      style([
        listStyleType(`none),
        flexWrap(`wrap),
        display(`flex),
        justifyContent(`flexStart),
        width(`percent(110.)),
        marginLeft(`rem(-2.)),
      ]);

    let postItem = style([width(`rem(25.)), marginBottom(`rem(3.25)), padding2(~h=`rem(2.), ~v=`zero)]);
  };

  module Content = {
    [@react.component]
    let make = (~posts) => {
      <ul className=Styles.postList>
        {posts
         |> Array.map(item => {
              <li
                className=Styles.postItem key={item.ContentType.BlogPost.slug}>
                <ListModule.MainListing
                  item
                  mainImg="/static/img/ArticleImageSmall.png"
                  itemKind=ListModule.Blog
                />
              </li>
            })
         |> React.array}
      </ul>;
    };
  };

  [@react.component]
  let make = (~posts) => {
    <div className=Style.container>
      <BlogModule.Title
        copy="More Blog posts"
        buttonCopy="See all posts"
        buttonHref="/blog/all"
      />
      <Content posts />
    </div>;
  };
};

module List = {
  include List;

  let take = (n, t) => {
    let rec go = (n, t, acc) =>
      if (n == 0) {
        List.rev(acc);
      } else {
        switch (t) {
        | [] => []
        | [x, ...xs] => go(n - 1, xs, [x, ...acc])
        };
      };
    go(n, t, []);
  };
};

module InternalCtaSection = {
  [@react.component]
  let make = () => {
    <InternalCtaSection
      leftItem=InternalCtaSection.Item.{
        title: "About the Tech",
        img: "/static/img/AboutTechCta.png",
        snippet: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      }
      rightItem=InternalCtaSection.Item.{
        title: "Get Started",
        img: "/static/img/GetStartedCta.png",
        snippet: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
      }
    />;
  };
};

[@react.component]
let make = (~posts) => {
  switch (Array.to_list(posts)) {
  | [] => failwith("Didn't load blog posts")
  | [featured, ...posts] =>
    <Page title="Coda Protocol Blog">
      <Next.Head> Markdown.katexStylesheet </Next.Head>
      <div className=Nav.Styles.spacerLarge />
      <FeaturedSingleRow
        row=FeaturedSingleRow.Row.{
          rowType: ImageLeftCopyRight,
          copySize: `Large,
          title: featured.ContentType.BlogPost.title,
          description: featured.snippet,
          textColor: Theme.Colors.white,
          image: "/static/img/BlogLandingHero.png",
          background: Image("/static/img/MinaSimplePattern1.png"),
          contentBackground: Image("/static/img/MinaSepctrumSecondary.png"),
          button: {
            buttonColor: Theme.Colors.orange,
            buttonTextColor: Theme.Colors.white,
            buttonText: "Read more",
            dark: true,
            href:
              {Js.log("/blog/" ++ featured.slug);
               "/blog/" ++ featured.slug},
          },
        }
      />
      <Wrapped>
        <div className=Style.morePostsSpacing>
          <MorePosts posts={List.take(9, posts) |> Array.of_list} />
        </div>
      </Wrapped>
      <ButtonBar
        kind=ButtonBar.CommunityLanding
        backgroundImg="/static/img/ButtonBarBackground.png"
      />
      <InternalCtaSection />
    </Page>
  };
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
