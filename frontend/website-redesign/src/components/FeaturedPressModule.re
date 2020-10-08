type state = {blogs: array(ContentType.BlogPost.entries)};

module Fetch =
       (
         T: {
           type t;
           let id: string;
           let dateKeyName: string;
         },
       ) => {
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

  let container =
    style([
      margin2(~v=`rem(7.), ~h=`zero),
      backgroundImage(
        `url("/static/img/backgrounds/SectionFeaturedEvent.jpg"),
      ),
      backgroundSize(`cover),
    ]);

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

module FetchPress = Fetch(ContentType.Press);

[@react.component]
let make = () => {
  let (content, setContent) = React.useState(_ => [||]);

  React.useEffect0(() => {
    FetchPress.run()
    |> Promise.iter(press =>
         setContent(_ =>
           press |> Array.map(ContentType.NormalizedPressBlog.ofPress)
         )
       );

    None;
  });

  <div className=Styles.container>
    <Wrapped>
      <div className=Styles.header>
        <h2 className=Theme.Type.h2> {React.string("Featured Press")} </h2>
      </div>
    </Wrapped>
    <MediaModule items=content itemKind=MediaModule.Blog />
  </div>;
};
