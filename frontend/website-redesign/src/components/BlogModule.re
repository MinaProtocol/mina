type state = {blogs: array(ContentType.BlogPost.entries)};

[@react.component]
let make = () => {
  let (blogs, setBlogs) = React.useState(_ => [||]);

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
         Array.map(
           (e: ContentType.BlogPost.entry) => e.fields,
           entries.items,
         )
       });
  };

  React.useEffect0(() => {
    fetchBlogs() |> Promise.iter(blogs => setBlogs(_ => blogs));
    None;
  });
  <div> <ListModule items=blogs /> </div>;
};
