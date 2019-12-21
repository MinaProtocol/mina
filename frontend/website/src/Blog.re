let extraHeaders = () =>
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
    <link rel="stylesheet" href={Links.Cdn.url("/static/css/blog.css")} />
    {Head.legacyStylesheets()}
  </>;

let titleColor = c => Css.unsafe("--title-color", Style.Colors.string(c));
let readMoreColor = c =>
  Css.unsafe("--read-more-color", Style.Colors.string(c));

// Truncate HTML
let rec truncate = (index, counter, html) =>
  if (counter == 0) {
    Js.String.substring(~from=0, html, ~to_=index + 4);
  } else {
    let indexOf = Js.String.indexOfFrom("</p>", index, html);
    if (indexOf !== (-1)) {
      truncate(indexOf + 1, counter - 1, html);
    } else {
      html;
    };
  };

// Need to dangerouslySetInnerHTML to handle html entities in the markdown
let createPostHeader = metadata =>
  <div className={Css.style([Css.width(`percent(100.))])}>
    <h1
      className=Css.(
        style([
          margin(`zero),
          fontSize(`rem(2.25)),
          Style.Typeface.ibmplexsans,
          fontWeight(`semiBold),
          letterSpacing(`rem(-0.0625)),
          width(`percent(100.)),
          unsafe("color", "var(--title-color)"),
          media(Style.MediaQuery.notMobile, [fontSize(`rem(3.))]),
        ])
      )
      dangerouslySetInnerHTML={"__html": metadata.BlogPost.title}
    />
    {switch (metadata.subtitle) {
     | None => React.null
     | Some(subtitle) =>
       <h2
         className=Css.(
           merge([
             Style.Body.big,
             style([margin(`zero), fontWeight(`normal)]),
           ])
         )
         dangerouslySetInnerHTML={"__html": subtitle}
       />
     }}
    <h3
      className=Css.(
        style([
          Style.Typeface.ibmplexsans,
          fontSize(`rem(0.75)),
          letterSpacing(`rem(0.0875)),
          fontWeight(`normal),
          color(Style.Colors.slate),
          marginTop(`rem(1.5)),
          textTransform(`uppercase),
        ])
      )>
      {React.string("by " ++ metadata.author ++ " ")}
    </h3>
    <h3
      className=Css.(
        style([
          Style.Typeface.ibmplexsans,
          fontSize(`rem(0.75)),
          letterSpacing(`rem(0.0875)),
          fontWeight(`normal),
          color(Style.Colors.slateAlpha(0.5)),
        ])
      )>
      {React.string(metadata.date)}
    </h3>
  </div>;

let createPostFadedContents = html =>
  <div
    className=Css.(
      style([
        height(`rem(10.5)),
        width(`percent(100.)),
        position(`relative),
        overflow(`hidden),
        marginTop(`rem(1.)),
      ])
    )>
    <div
      className=Css.(
        style([
          after([
            contentRule(""),
            position(`absolute),
            zIndex(1),
            // Needed to prevent the bottom of the text peeking through for some reason.
            bottom(`px(-1)),
            left(`zero),
            height(`rem(4.75)),
            width(`percent(100.)),
            backgroundImage(
              `linearGradient((
                `deg(0),
                [
                  (0, Style.Colors.white),
                  (100, Style.Colors.whiteAlpha(0.)),
                ],
              )),
            ),
          ]),
        ])
      )>
      <div
        className={
          "blog-content "
          ++ Css.(
               style([
                 Style.Typeface.ibmplexsans,
                 lineHeight(`rem(1.5)),
                 color(Style.Colors.saville),
                 boxSizing(`contentBox),
               ])
             )
        }
        dangerouslySetInnerHTML={"__html": truncate(0, 5, html)} //set to truncated html to save rendering time
      />
    </div>
  </div>;

// Uses an overlay link to avoid nesting anchor tags
let createPostSummary = ((name, html, metadata)) => {
  <div key=name className=Css.(style([position(`relative)]))>
    <A
      name={"blog-" ++ name}
      href={"/blog/" ++ name ++ ".html"}
      className=Css.(
        style([
          position(`absolute),
          left(`zero),
          right(`zero),
          top(`zero),
          bottom(`zero),
          // display(`block),
          selector(
            ":hover + div",
            [
              color(Style.Colors.hyperlink),
              titleColor(Style.Colors.hyperlink),
              readMoreColor(Style.Colors.hyperlinkHover),
            ],
          ),
        ])
      )
    />
    <div
      className=Css.(
        style([
          position(`relative),
          pointerEvents(`none),
          display(`flex),
          alignItems(`flexStart),
          flexDirection(`column),
          marginBottom(`rem(4.)),
          color(Style.Colors.saville),
          titleColor(Style.Colors.saville),
          readMoreColor(Style.Colors.hyperlink),
        ])
      )>
      {createPostHeader(metadata)}
      {createPostFadedContents(html)}
      <div
        className=Css.(
          style([
            marginTop(`rem(1.)),
            Style.Typeface.ibmplexsans,
            fontWeight(`medium),
            fontSize(`rem(1.)),
            letterSpacing(`rem(-0.0125)),
            unsafe("color", "var(--read-more-color)"),
          ])
        )>
        {React.string({js|Read more →|js})}
      </div>
    </div>
  </div>;
};

[@react.component]
let make = (~posts) => {
  <div
    className=Css.(
      style([
        display(`flex),
        flexDirection(`column),
        alignItems(`stretch),
        maxWidth(`rem(43.)),
        marginLeft(`auto),
        marginRight(`auto),
        media(Style.MediaQuery.full, [marginTop(`rem(2.0))]),
      ])
    )>
    <div>
      {React.array(Array.of_list(List.map(createPostSummary, posts)))}
    </div>
    BlogPost.renderKatex
  </div>;
};
