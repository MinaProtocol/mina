module Footer = {
  let newsletterSectionStyle =
    Css.(
      style([
        width(`percent(100.0)),
        backgroundColor(`hex("424242")),
        paddingTop(`rem(3.5)),
        paddingBottom(`rem(3.5)),
        display(`flex),
        justifyContent(`center),
        flexWrap(`wrap),
        alignItems(`flexStart),
      ])
    );
  let footerSectionStyle =
    Css.(
      style([
        width(`percent(100.0)),
        backgroundColor(`hex("212121")),
        display(`flex),
        paddingTop(`rem(3.5)),
        paddingBottom(`rem(4.0)),
        media(
          Theme.MediaQuery.notMobile,
          [paddingLeft(`rem(1.0)), paddingRight(`rem(1.0))],
        ),
        media(
          Theme.MediaQuery.full,
          [paddingLeft(`rem(5.0)), paddingRight(`rem(5.0))],
        ),
        media(
          Theme.MediaQuery.veryLarge,
          [paddingLeft(`rem(8.0)), paddingRight(`rem(8.0))],
        ),
      ])
    );
  [@react.component]
  let make = () => {
    <footer>
      <section className=newsletterSectionStyle>
        <NewsletterWidget center=true whiteText=true />
      </section>
      <section className=footerSectionStyle>
        <div className=Theme.Grid.gridParent>
          <div
            className={Css.merge([Theme.Grid.mobileFullWidth, Theme.Grid.x8])}>
            {React.string("One")}
          </div>
          <div
            className={Css.merge([Theme.Grid.mobileFullWidth, Theme.Grid.x2])}>
            {React.string("Two")}
          </div>
        </div>
      </section>
    </footer>;
  };
};