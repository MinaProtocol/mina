module Footer = {
  module Link = {
    let component = ReasonReact.statelessComponent("Page.Footer.Link");
    let footerStyle =
      Css.(
        style([
          Style.Typeface.ibmplexsans,
          color(Style.Colors.slate),
          textDecoration(`none),
          display(`inline),
          hover([color(Style.Colors.hyperlink)]),
          fontSize(`rem(1.0)),
          fontWeight(`light),
          lineHeight(`rem(1.56)),
        ])
      );
    let make = (~last=false, ~link, ~name, children) => {
      ...component,
      render: _self =>
        <li className=Css.(style([display(`inline)]))>
          <a
            href=link
            className=footerStyle
            name={"footer-" ++ name}
            target="_blank">
            ...children
          </a>
          {last
             ? ReasonReact.null
             : <span className=footerStyle>
                 {ReasonReact.string({js| · |js})}
               </span>}
        </li>,
    };
  };

  let component = ReasonReact.statelessComponent("Page.Footer");
  let make = (~bgcolor, _children) => {
    ...component,
    render: _self =>
      <footer className=Css.(style([backgroundColor(bgcolor)]))>
        <section
          className=Css.(
            style(
              [
                maxWidth(`rem(96.0)),
                marginLeft(`auto),
                marginRight(`auto),
                ...Style.paddingY(`rem(2.)),
              ]
              @ Style.paddingX(`rem(4.0)),
            )
          )>
          <div
            className=Css.(
              style([
                display(`flex),
                justifyContent(`center),
                textAlign(`center),
                marginBottom(`rem(2.0)),
              ])
            )>
            <ul
              className=Css.(
                style([listStyleType(`none), ...Style.paddingX(`zero)])
              )>
              <Link link="mailto:contact@o1labs.org" name="mail">
                {ReasonReact.string("contact@o1labs.org")}
              </Link>
              <Link link="https://o1labs.org" name="o1www">
                {ReasonReact.string("o1labs.org")}
              </Link>
              <Link link="https://twitter.com/codaprotocol" name="twitter">
                {ReasonReact.string("Twitter")}
              </Link>
              <Link link="https://github.com/o1-labs" name="github">
                {ReasonReact.string("GitHub")}
              </Link>
              <Link link="https://reddit.com/r/coda" name="reddit">
                {ReasonReact.string("Reddit")}
              </Link>
              <Link link="https://t.me/codaprotocol" name="telegram">
                {ReasonReact.string("Telegram")}
              </Link>
              <Link link="/tos.html" name="tos">
                {ReasonReact.string("Terms of service")}
              </Link>
              <Link link="/privacy.html" name="privacy">
                {ReasonReact.string("Privacy Policy")}
              </Link>
              <Link link="/jobs.html" name="hiring" last=true>
                {ReasonReact.string("We're Hiring")}
              </Link>
            </ul>
          </div>
        </section>
      </footer>,
  };
};

let component = ReasonReact.statelessComponent("Page");
let make =
    (
      ~name,
      ~extraHeaders=ReasonReact.null,
      ~footerColor=Style.Colors.white,
      children,
    ) => {
  ...component,
  render: _ =>
    <html
      className=Css.(
        style([
          media(Style.MediaQuery.iphoneSEorSmaller, [fontSize(`px(13))]),
        ])
      )>
      <Head filename=name extra=extraHeaders />
      <body>
        {if (Grid.enabled) {
           <div
             className=Css.(
               style([
                 position(`absolute),
                 top(`zero),
                 width(`percent(100.0)),
                 height(`percent(100.0)),
               ])
             )>
             <div
               className=Css.(
                 style([
                   position(`relative),
                   marginRight(`auto),
                   marginLeft(`auto),
                   height(`percent(100.0)),
                   width(`percent(100.0)),
                   maxWidth(`rem(84.0)),
                   before(Grid.overlay),
                 ])
               )
             />
           </div>;
         } else {
           <div />;
         }}
        <Wrapped>
          <div
            className=Css.(
              style([
                marginTop(`rem(1.0)),
                media(Style.MediaQuery.full, [marginTop(`rem(2.0))]),
              ])
            )>
            <CodaNav />
          </div>
        </Wrapped>
        <div> ...children </div>
        <Footer bgcolor=footerColor />
      </body>
    </html>,
};
