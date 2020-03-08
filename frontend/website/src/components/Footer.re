/*module Footer = {
    module Link = {
      let footerStyle =
        Css.(
          style([
            Theme.Typeface.ibmplexsans,
            color(Theme.Colors.slate),
            textDecoration(`none),
            display(`inline),
            hover([color(Theme.Colors.hyperlink)]),
            fontSize(`rem(1.0)),
            fontWeight(`light),
            lineHeight(`rem(1.56)),
          ])
        );
      [@react.component]
      let make = (~last=false, ~link, ~name, ~children) => {
        <li className=Css.(style([display(`inline)]))>
          <a
            href=link
            className=footerStyle
            name={"footer-" ++ name}
            target="_blank">
            children
          </a>
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
                // Not using Theme.paddingY here because we need the background
                // color the same (so can't use margin), but we also need some
                // top spacing.
                paddingTop(`rem(4.75)),
                paddingBottom(`rem(2.)),
              ]
              @ Theme.paddingX(`rem(4.0)),
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
                style([listStyleType(`none), ...Theme.paddingX(`zero)])
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
              <Link link="/tos" name="tos">
                {React.string("Terms of service")}
              </Link>
              <Link link="/privacy" name="privacy">
                {React.string("Privacy Policy")}
              </Link>
              <Link link="/jobs" name="hiring">
                {React.string("We're Hiring")}
              </Link>
              <Link
                link="https://s3.us-east-2.amazonaws.com/static.o1test.net/presskit.zip"
                name="presskit"
                last=true>
                {React.string("Press Kit")}
              </Link>
            </ul>
          </div>
          <p
            className=Css.(
              merge([
                Theme.Body.small,
                style([textAlign(`center), color(Theme.Colors.saville)]),
              ])
            )>
            {React.string({j|© 2020 O(1) Labs|j})}
          </p>
        </section>
      </footer>;
    };
  };*/
module Footer = {
  let newsletterSectionStyle =
    Css.(
      style([
        width(`percent(100.0)),
        backgroundColor(`hex("424242")),
        paddingTop(`rem(3.0)),
        paddingBottom(`rem(2.0)),
        display(`flex),
      ])
    );
  let footerSectionStyle =
    Css.(
      style([
        Theme.Typeface.ibmplexsans,
        color(Theme.Colors.slate),
        textDecoration(`none),
        display(`inline),
        hover([color(Theme.Colors.hyperlink)]),
        fontSize(`rem(1.0)),
        fontWeight(`light),
        lineHeight(`rem(1.56)),
      ])
    );
  [@react.component]
  let make = () => {
    <footer>
      <section className=newsletterSectionStyle>
        <NewsletterWidget center=true whiteText=true />
      </section>
      <section className=footerSectionStyle>
        {React.string("This is normal footer section")}
      </section>
    </footer>;
  };
};