module Footer = {
  module Link = {
    let component = ReasonReact.statelessComponent("Page.Footer.Link");
    let footerStyle =
      Css.(
        style([
          Style.Typeface.ibmplexsans,
          color(Style.Colors.slate),
          textDecoration(`none),
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
      <div
        className=Css.(
          style([backgroundColor(bgcolor), boxSizing(`contentBox)])
        )>
        <section
          className=Css.(
            style(
              [
                marginTop(`rem(2.)),
                boxSizing(`borderBox),
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
      </div>,
  };
};

module Wrapped = {
  module Style = {
    open Css;
    open Style;

    let s =
      style(
        paddingX(`rem(1.25))
        @ [
          margin(`auto),
          media(
            MediaQuery.full,
            [
              maxWidth(`rem(84.0)),
              margin(`auto),
              ...paddingX(`rem(2.0)),
            ],
          ),
        ],
      );
  };

  let component = ReasonReact.statelessComponent("Page.Wrapped");
  let make = children => {
    ...component,
    render: _ => {
      <div className=Style.s> ...children </div>;
    },
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
    <html>
      <Head filename=name extra=extraHeaders />
      <body>
        <Wrapped> <CodaNav /> <div> ...children </div> </Wrapped>
        <Footer bgcolor=footerColor />
      </body>
    </html>,
};
