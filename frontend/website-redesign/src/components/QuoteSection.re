module Styles = {
  open Css;

  // TODO: Fix background sizes once wrapper is merged in
  let container =
    style([
      display(`flex),
      alignItems(`center),
      justifyContent(`center),
      position(`relative),
      important(backgroundSize(`cover)),
      background(`url("/static/img/SectionQuoteMobile.png")),
      padding2(~v=`rem(4.), ~h=`rem(1.5)),
      media(
        Theme.MediaQuery.tablet,
        [
          background(`url("/static/img/SectionQuoteTablet.png")),
          height(`rem(42.)),
        ],
      ),
      media(
        Theme.MediaQuery.desktop,
        [
          justifyContent(`flexEnd),
          alignContent(`spaceAround),
          padding2(~v=`zero, ~h=`rem(9.5)),
          background(`url("/static/img/SectionQuoteDesktop.png")),
        ],
      ),
    ]);

  let headshot =
    style([
      height(`rem(3.5)),
      media(Theme.MediaQuery.tablet, [height(`rem(5.5))]),
    ]);

  /**
   * This is the actual white box of the quote section
   */
  let quoteContainer = small =>
    style([
      background(white),
      padding(`rem(1.)),
      media(
        Theme.MediaQuery.tablet,
        [
          padding4(
            ~top=`rem(2.5),
            ~right=`rem(2.5),
            ~bottom=`rem(2.5),
            ~left=`rem(4.5),
          ),
          width(`rem(43.)),
        ],
      ),
      media(Theme.MediaQuery.desktop, [width(small ? `rem(47.) : auto)]),
    ]);

  let quote =
    merge([
      Theme.Type.quote,
      style([fontSize(`rem(1.3)), marginBottom(`rem(1.))]),
    ]);

  let attribute =
    style([
      display(`flex),
      flexDirection(`row),
      alignItems(`center),
      justifyContent(`flexStart),
      marginLeft(`rem(1.25)),
      media(
        Theme.MediaQuery.tablet,
        [marginLeft(`zero), left(`rem(4.56)), top(`rem(19.6))],
      ),
      media(
        Theme.MediaQuery.desktop,
        [left(`rem(4.56)), top(`rem(16.5))],
      ),
    ]);

  let name =
    style([
      marginLeft(`rem(1.5)),
      marginTop(`rem(1.)),
      media(Theme.MediaQuery.tablet, [marginTop(`zero)]),
    ]);
};

[@react.component]
let make = (~small=true) => {
  <div className=Styles.container>
    <div className={Styles.quoteContainer(small)}>
      <p className=Styles.quote>
        {React.string(
           "\"What attracted me was a small, scalable blockchain that's still independently verifiable on small nodes.\"",
         )}
      </p>
      <div className=Styles.attribute>
        <img className=Styles.headshot src="/static/img/headshots/naval.jpg" />
        <div className=Styles.name>
          <p className=Theme.Type.pageLabel>
            {React.string("Naval Ravikant")}
          </p>
          <p className=Theme.Type.contributorLabel>
            {React.string("AngelList Co-Founder")}
          </p>
        </div>
      </div>
    </div>
  </div>;
};
