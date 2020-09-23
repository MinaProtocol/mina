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
       let posts =
         Array.map(
           (e: ContentType.BlogPost.entry) => e.fields,
           entries.items,
         );
       {"posts": posts};
     });
};

[@react.component]
let make = () => {
  React.useEffect0(() => {
    let blogs = fetchBlogs();
    Js.log(blogs);
    None;
  });
  <div> <ListModule /> </div>;
};
