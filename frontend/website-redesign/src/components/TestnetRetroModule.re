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
    fetchBlogs()
    |> Promise.iter(blogs => {
         let filteredBlogs =
           Belt.Array.keep(blogs, (blog: ContentType.BlogPost.t) => {
             Js.String.includes(
               String.lowercase_ascii("testnet"),
               String.lowercase_ascii(blog.title),
             )
           });
         setBlogs(_ =>
           filteredBlogs |> Array.map(ContentType.NormalizedPressBlog.ofBlog)
         );
       });
    None;
  });

  <div className=Styles.container>
    <Wrapped>
      <div className=Styles.header>
        <h2 className=Theme.Type.h2>
          {React.string("Testnet Retros & Release Notes")}
        </h2>
      </div>
    </Wrapped>
    <ListModule items=blogs itemKind=ListModule.TestnetRetro />
  </div>;
};
