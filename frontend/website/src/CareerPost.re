let component = ReasonReact.statelessComponent("CareerPost");

let extraHeaders = () => Head.legacyStylesheets();

let make = (~path, _) => {
  let (html, content) = Markdown.load(path);
  let title = Markdown.Metadata.getRequiredValue("title", content, path);
  // HACK: In an attempt to make the job post page passable for a quick deploy, I forced some extra CSS in a style tag on the top.
  {
    ...component,
    render: _self =>
      <>
        <style>
          {ReasonReact.string(
             {css|
main h2 {
  margin-top: 1.5rem;
  margin-bottom: 1.5rem;
}

ul li {
  margin-left: 1.25rem;
}     |css},
           )}
        </style>
        <div className="bxs-cb bg-white">
          <section
            className="section-wrapper pv4 mw9 center bxs-bb ph3-l ph2-m mw9-l">
            <div className="center mw7">
              <div className="important-text">
                <div>
                  <div className="dn db-ns">
                    <h1
                      className={
                        "dib mw6 m-none mb3 mb4-ns mt0 mr0 ml0 "
                        ++ Css.(
                             merge([
                               Style.H1.hero,
                               style([color(Style.Colors.saville)]),
                             ])
                           )
                      }>
                      {ReasonReact.string(title)}
                    </h1>
                  </div>
                  <div className="db dn-ns">
                    <h1
                      className={
                        "dib mw6 m-none mb3 mb4-ns mt0 mr0 ml0 "
                        ++ Css.(
                             merge([
                               Style.H1.hero,
                               style([color(Style.Colors.saville)]),
                             ])
                           )
                      }>
                      {ReasonReact.string(title)}
                    </h1>
                  </div>
                </div>
                <div className={"mt0 mr0 ml0 " ++ Style.Body.big}>
                  <p
                    className="mt0 mb0"
                    dangerouslySetInnerHTML={"__html": html}
                  />
                </div>
              </div>
            </div>
          </section>
        </div>
      </>,
  };
};
