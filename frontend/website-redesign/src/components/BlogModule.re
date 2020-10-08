type state = {blogs: array(ContentType.BlogPost.entries)};

module Fetch = (T: {
                  type t;
                  let id: string;
                  let dateKeyName: string;
                }) => {
  let run = () => {
    Contentful.getEntries(
      Lazy.force(Contentful.client),
      {
        "include": 0,
        "content_type": T.id,
        "order": "-fields." ++ T.dateKeyName,
      },
    )
    |> Promise.map((entries: ContentType.System.entries(T.t)) => {
         Array.map(
           (e: ContentType.System.entry(T.t)) => e.fields,
           entries.items,
         )
       });
  };
};

module Styles = {
  open Css;

  let container = style([margin2(~v=`rem(7.), ~h=`zero)]);

  let header =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      alignItems(`center),
      width(`percent(100.)),
      marginBottom(`rem(3.)),
      media(Theme.MediaQuery.notMobile, [width(`percent(93.))]),
    ]);
};

module Title = {
  [@react.component]
  let make = (~copy, ~buttonCopy, ~buttonHref) => {
    <div className=Styles.header>
      <h2 className=Theme.Type.h2> {React.string(copy)} </h2>
      <Button bgColor=Theme.Colors.digitalBlack href=buttonHref>
        {React.string(buttonCopy)}
        <Icon kind=Icon.ArrowRightMedium />
      </Button>
    </div>;
  };
};
module FetchAnnouncements = Fetch(ContentType.Announcement);
module FetchBlogs = Fetch(ContentType.BlogPost);
module FetchPress = Fetch(ContentType.Press);

[@react.component]
let make = (~source, ~title="In the News", ~itemKind=ListModule.Blog) => {
  let (content, setContent) = React.useState(_ => [||]);

  React.useEffect0(() => {
    switch (source) {
    | `Blogs =>
      FetchBlogs.run()
      |> Promise.iter(blogs =>
           setContent(_ =>
             blogs |> Array.map(ContentType.NormalizedPressBlog.ofBlog)
           )
         )
    | `Press =>
      FetchPress.run()
      |> Promise.iter(press =>
           setContent(_ =>
             press |> Array.map(ContentType.NormalizedPressBlog.ofPress)
           )
         )
    | `Announcement =>
      FetchAnnouncements.run()
      |> Promise.iter(announcement =>
           setContent(_ =>
             announcement
             |> Array.map(ContentType.NormalizedPressBlog.ofAnnouncement)
           )
         )
    };

    None;
  });

  <div className=Styles.container>
    <Wrapped>
      <Title
        copy=title
        buttonCopy="See All Press"
        buttonHref={`Internal("/blog")}
      />
    </Wrapped>
    <ListModule items=content itemKind />
  </div>;
};
