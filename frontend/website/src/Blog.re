let extraHeaders =
  <>
    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.css"
      integrity="sha384-9eLZqc9ds8eNjO3TmqPeYcDj8n+Qfa4nuSiGYa6DjLNcv9BtN69ZIulL9+8CqC9Y"
      crossOrigin="anonymous"
    />
    <script
      defer=true
      src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.js"
      integrity="sha384-K3vbOmF2BtaVai+Qk37uypf7VrgBubhQreNQe9aGsz9lB63dIFiQVlJbr92dw2Lx"
      crossOrigin="anonymous"
    />
    <script
      defer=true
      src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/contrib/auto-render.min.js"
      integrity="sha384-kmZOZB5ObwgQnS/DuDg6TScgOiWWBiVt0plIRkZCmE6rDZGrEOQeHM5PcHi+nyqe"
      crossOrigin="anonymous"
    />
    <link rel="stylesheet" href="/static/css/blog.css" />
    Head.legacyStylesheets
  </>;

let component = ReasonReact.statelessComponent("Blog");

let previousPost = (metadata: BlogPost.metadata) =>
  <>
    <h2
      className="f3 ddinexp tracked-tightish pt2 pt3-m pt4-l mt1 mb1"
      dangerouslySetInnerHTML={"__html": metadata.title}
    />
    {switch (metadata.subtitle) {
     | None => ReasonReact.null
     | Some(subtitle) =>
       <h3
         className="f5 f4-ns ddinexp mt0 mb1 fw4"
         dangerouslySetInnerHTML={"__html": subtitle}
       />
     }}
    <h5
      className="f8 f7-ns nowrap fw4 tracked-supermega ttu metropolis mt0 mb4 mb1-ns">
      <span className="mr2">
        {ReasonReact.string("by " ++ metadata.author ++ " ")}
      </span>
      <span className="fr"> {ReasonReact.string(metadata.date)} </span>
    </h5>
  </>;

let make = (~posts, children) => {
  let sortedPosts =
    List.sort(
      ((_, _, metadata1), (_, _, metadata2)) => {
        let date1 = Js.Date.fromString(metadata1.BlogPost.date);
        let date2 = Js.Date.fromString(metadata2.date);
        let diff = Js.Date.getTime(date2) -. Js.Date.getTime(date1);
        if (diff > 0.) {
          1;
        } else if (diff < 0.) {
          (-1);
        } else {
          0;
        };
      },
      posts,
    );
  {
    ...component,
    render: _self =>
      switch (sortedPosts) {
      | [] => failwith("No blog posts found")
      | [(name, html, metadata)] => <BlogPost name html metadata />
      | [(name, html, metadata), ...tl] =>
        <div>
          <BlogPost name html metadata showComments=false />
          <h3
            className="f4 f3-ns ddinexp mt0 mb0 fw4 mw65 center pt3 pt4-m pt5-l">
            {ReasonReact.string("Previous Posts:")}
          </h3>
          <div className="mw65 center ph3 ph4-m ph5-l">
            <ul className="list lh-copy">
              ...{Array.of_list(
                List.map(
                  ((name, html, metadata)) =>
                    <li>
                      <a
                        href={"/blog/" ++ name ++ ".html"}
                        className="f5 dodgerblue fw5 no-underline hover-link">
                        {previousPost(metadata)}
                      </a>
                    </li>,
                  tl,
                ),
              )}
            </ul>
          </div>
        </div>
      },
  };
};
