type state = {blogs: array(ContentType.BlogPost.entries)};

let fetchBlogs = () => {
  Contentful.getEntries(
    Lazy.force(Contentful.client),
    {
      "include": 0,
      "content_type": ContentType.BlogPost.id,
      "order": "-fields.date",
    },
  )
  |> Promise.map((entries: ContentType.BlogPost.entries) => {
       Array.map((e: ContentType.BlogPost.entry) => e.fields, entries.items)
     });
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
    ]);
};

[@react.component]
let make = () => {
  let (blogs, setBlogs) = React.useState(_ => [||]);

  React.useEffect0(() => {
    fetchBlogs() |> Promise.iter(blogs => setBlogs(_ => blogs));
    None;
  });

  <div className=Styles.container>
    <Wrapped>
      <div className=Styles.header>
        <h2 className=Theme.Type.h2> {React.string("In the News")} </h2>
        <Button bgColor=Theme.Colors.digitalBlack href="/blog">
          {React.string("See All Press")}
          <Icon kind=Icon.ArrowRightMedium />
        </Button>
      </div>
    </Wrapped>
    <ListModule items=blogs mainImg="/static/img/ArticleImage.png" />
  </div>;
};
