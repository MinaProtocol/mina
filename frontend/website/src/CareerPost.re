let component = ReasonReact.statelessComponent("CareerPost");

let make = (~path, _) => {
  let (html, content) = Markdown.load(path);
  let title = Markdown.Metadata.getRequiredValue("title", content, path);
  {
    ...component,
    render: _self =>
      <div className="bxs-cb bg-white">
        <section
          className="section-wrapper pv4 mw9 center bxs-bb ph6-l ph5-m ph4 mw9-l">
          <div className="center mw7">
            <div className="important-text">
              <div>
                <div className="dn db-ns">
                  <h3
                    className="dib mw6 m-none lh-copy f2 mb3 mb4-ns tc tl-ns mt0 mr0 ml0">
                    {ReasonReact.string(title)}
                  </h3>
                </div>
                <div className="db dn-ns">
                  <div className="flex justify-center">
                    <h3
                      className="dib mw6 m-none lh-copy f2 mb3 mb4-ns tc tl-ns mt0 mr0 ml0">
                      {ReasonReact.string(title)}
                    </h3>
                  </div>
                </div>
              </div>
              <div className="lh-copy f4 fw3 silver tc tl-ns mt0 mr0 ml0">
                <p
                  className="mt0 mb0"
                  dangerouslySetInnerHTML={"__html": html}
                />
              </div>
            </div>
          </div>
        </section>
        <BlogPost.MailingList />
      </div>,
  };
};
