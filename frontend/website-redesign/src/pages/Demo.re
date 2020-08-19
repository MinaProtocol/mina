module Styles = {
  open Css;
  let page =
    style([
      marginLeft(`auto),
      marginRight(`auto),
      media(Theme.MediaQuery.tablet, [maxWidth(`rem(68.))]),
    ]);
};

[@react.component]
let make = (~profiles) => {
  <Page
    title="Genesis"
    description="Join Genesis. Become one of 1000 community members to receive a grant of 66,000 coda tokens. You'll participate in activities that will strengthen the Coda network and community.">
    <Wrapped>
      <div className=Styles.page>
       </div>
    </Wrapped>
  </Page>;
};