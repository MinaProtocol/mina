module Footer = {
  module Link = {
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
    [@react.component]
    let make = (~last=false, ~link, ~name, ~children) => {
      <li className=Css.(style([display(`inline)]))>
        <A
          href=link
          className=footerStyle
          name={"footer-" ++ name}
          target="_blank">
          children
        </A>
        {last
           ? React.null
           : <span className=footerStyle ariaHidden=true>
               {React.string({js| · |js})}
             </span>}
      </li>;
    };
  };

  [@react.component]
  let make = (~bgcolor) => {
    <footer className=Css.(style([backgroundColor(bgcolor)]))>
      <section
        className=Css.(
          style(
            [
              maxWidth(`rem(96.0)),
              marginLeft(`auto),
              marginRight(`auto),
              // Not using Style.paddingY here because we need the background
              // color the same (so can't use margin), but we also need some
              // top spacing.
              paddingTop(`rem(4.75)),
              paddingBottom(`rem(2.)),
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
              {React.string("contact@o1labs.org")}
            </Link>
            <Link link="https://o1labs.org" name="o1www">
              {React.string("o1labs.org")}
            </Link>
            <Link link="https://twitter.com/codaprotocol" name="twitter">
              {React.string("Twitter")}
            </Link>
            <Link link="https://github.com/CodaProtocol/coda" name="github">
              {React.string("GitHub")}
            </Link>
            <Link link="https://forums.codaprotocol.com" name="discourse">
              {React.string("Discourse")}
            </Link>
            <Link link="https://reddit.com/r/coda" name="reddit">
              {React.string("Reddit")}
            </Link>
            <Link link="https://t.me/codaprotocol" name="telegram">
              {React.string("Telegram")}
            </Link>
            <Link link="/tos.html" name="tos">
              {React.string("Terms of service")}
            </Link>
            <Link link="/privacy.html" name="privacy">
              {React.string("Privacy Policy")}
            </Link>
            <Link link="/jobs.html" name="hiring">
              {React.string("We're Hiring")}
            </Link>
            <Link
              link={Links.Cdn.url("/static/presskit.zip")}
              name="presskit"
              last=true>
              {React.string("Press Kit")}
            </Link>
          </ul>
        </div>
        <p
          className=Css.(
            merge([
              Style.Body.small,
              style([textAlign(`center), color(Style.Colors.saville)]),
            ])
          )>
          {React.string({j|© 2019 O(1) Labs|j})}
        </p>
      </section>
    </footer>;
  };
};

[@react.component]
let make =
    (
      ~name,
      ~extraHeaders=React.null,
      ~footerColor=Style.Colors.white,
      ~page,
      ~children,
    ) => {
  <html
    lang="en"
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
              media(
                Style.MediaQuery.statusLiftAlways,
                [marginTop(`rem(2.0))],
              ),
            ])
          )>
          <Nav page />
        </div>
      </Wrapped>
      <main> children </main>
      <Footer bgcolor=footerColor />
    </body>
  </html>;
};
