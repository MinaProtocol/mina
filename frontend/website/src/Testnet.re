let extraHeaders = () =>
  <>
    <script src="https://apis.google.com/js/api.js" />
    <script src={Links.Cdn.url("/static/js/leaderboard.js")} />
  </>;

module Styles = {
  open Css;

  let header =
    style([
      display(`flex),
      flexDirection(`column),
      width(`percent(100.)),
      color(Style.Colors.slate),
      textAlign(`center),
      margin2(~v=rem(3.5), ~h=`zero),
      marginTop(rem(1.)),
    ]);

  let content =
    style([
      display(`flex),
      flexDirection(`columnReverse),
      justifyContent(`center),
      media(Style.MediaQuery.somewhatLarge, [flexDirection(`row)]),
    ]);

  let leaderboard =
    style([
      background(Style.Colors.hyperlinkAlpha(0.15)),
      width(`percent(100.)),
      maxWidth(rem(41.)),
      borderRadius(px(3)),
      padding2(~v=`rem(1.), ~h=`zero),
      Style.Typeface.pragmataPro,
      lineHeight(rem(1.5)),
      color(Style.Colors.midnight),
      selector(
        ".leaderboard-row",
        [
          display(`grid),
          gridColumnGap(rem(1.5)),
          gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(2.5)]),
        ],
      ),
      selector(
        "div span:last-child",
        [
          opacity(0.5),
        ],
      ),
      selector("div span:nth-child(odd)", [justifySelf(`flexEnd)]),
      selector(
        "hr",
        [
          height(px(4)),
          borderTop(px(1), `dashed, Style.Colors.marine),
          borderLeft(`zero, solid, transparent),
          borderBottom(px(1), `dashed, Style.Colors.marine),
        ],
      ),
      selector(
        "#leaderboard-loading",
        [
          textAlign(`center),
          marginTop(rem(2.)),
          color(Style.Colors.slateAlpha(0.7)),
        ],
      ),
      selector("div", [padding2(~v=`zero, ~h=`rem(1.))]),
      selector("div:nth-child(even)", [backgroundColor(`rgba(71, 130, 130, 0.1))]),
    ]);

  let headerRow =
    merge([
      Style.Body.basic_semibold,
      style([
        display(`grid),
        color(Style.Colors.midnight),
        gridColumnGap(rem(1.5)),
        gridTemplateColumns([rem(2.5), `auto, rem(6.), rem(2.5)]),
      ]),
    ]);

  let copy =
    style([
      width(rem(28.)),
      margin3(~top=`zero, ~h=`auto, ~bottom=rem(2.)),
      media(Style.MediaQuery.somewhatLarge, [marginLeft(rem(5.))]),
      ...Style.Body.basicStyles,
    ]);

  let leaderboardLink =
    merge([
      Style.Link.basic,
      Style.H3.basic,
      style([
        fontWeight(`semiBold),
        marginTop(rem(0.75)),
        marginLeft(rem(1.75)),
      ]),
    ]);

  let sidebarHeader = 
    merge([
      Style.H4.wide,
      style([
        textAlign(`left),
        fontSize(`rem(1.)),
        fontWeight(`light),
      ]),
    ]);
  
  let weekHeader =
    merge([
      Style.H2.basic,
      style([
        padding2(~v=`rem(1.), ~h=`zero),
      ]),
    ]);
};

let component = ReasonReact.statelessComponent("Testnet");
let make = _children => {
  ...component,
  render: _self => {
    <div>
      <div className=Styles.header>
        <h1 className=Style.H1.hero>
          {ReasonReact.string("Testnet Leaderboard")}
        </h1>
        <a
          href="https://docs.google.com/spreadsheets/d/1CLX9DF7oFDWb1UiimQXgh_J6jO4fVLJEcEnPVAOfq24/edit#gid=0"
          target="_blank"
          className=Styles.leaderboardLink
        >
          {ReasonReact.string({j|View Full Leaderboard\u00A0→|j})}
        </a>
      </div>
      <div className=Styles.content>
        <div id="testnet-leaderboard" className=Styles.leaderboard>
          <div className=Styles.headerRow>
            <span> {ReasonReact.string("Rank")} </span>
            <span> {ReasonReact.string("Username")} </span>
            <span id="leaderboard-current-week"></span>
            <span> {ReasonReact.string("Total")} </span>
          </div>
          <hr />
          <div id="leaderboard-loading">
            {ReasonReact.string("Loading...")}
          </div>
        </div>
        <div className=Styles.copy>
          <p> <h4 className=Styles.sidebarHeader> {ReasonReact.string("Testnet Points")} </h4> </p>
          <p>
            {ReasonReact.string(
               "The goal of Testnet Points* is to recognize Coda community members who are actively involved in the network. There will be regular challenges to make it fun, interesting, and foster some friendly competition! Points can be won in several ways like being first to complete a challenge, contributing code to Coda, or being an excellent community member and helping others out.",
             )}
          </p>
          
          <p> <h4 className=Styles.sidebarHeader> {ReasonReact.string("Community")} </h4> </p>
          <p>
            <a className=Style.Link.basic href="/docs"> {ReasonReact.string("Testnet Docs")} </a>
            <br/>
            <a className=Style.Link.basic href="https://bit.ly/CodaDiscord" target="_blank"> {ReasonReact.string("Discord")} </a>
            <br/>
            <a className=Style.Link.basic href="https://forums.codaprotocol.com" target="_blank"> {ReasonReact.string("Coda Forums")} </a>
          </p>

          <p> <h2 className=Styles.weekHeader> {ReasonReact.string("Week 5")} </h2> </p>

          <p> <h4 className=Styles.sidebarHeader> {ReasonReact.string("Challenge #12: 'CLI FYI'")} </h4> </p>
          <p>
            {ReasonReact.string(
              "Submit a product improvement or feature you'd like to see in the Coda command line interface (CLI). Post a new thread on the Discourse " 
            )}
            <a className=Style.Link.basic href="http://forums.codaprotocol.com" target="_blank">{ReasonReact.string("forums")}</a>
            {ReasonReact.string(
              " in the 'Product' category and add this to the title: '[CLI Feature]'. The community can vote on it by 'hearting' the post, and comment / discuss details in the thread. Add your Discord username to be counted for pts*."
            )}
          </p>
          <p>
            {ReasonReact.string(
              "Every feasible feature suggested will get 500 pts*. Top 5 features will win a bonus - and the community gets to vote for top 5. Bonus: 2500, 2000, 1500, 1000, 500 pts* respectively. Feasible feature means well scoped ideas that Coda could technically implement -- eg. The block producing CLI command should tell you % likelihood of winning a block and the time until the next slot you can produce blocks for. No guarantees that suggested features will be implemented. But if you submit a PR implementing one, you could win a massive bonus of 5000 pts*!"
            )}
          </p>

          <p> <h4 className=Styles.sidebarHeader> {ReasonReact.string("Challenge #13: 'My two codas'")} </h4> </p>
          <p>
            {ReasonReact.string(
              "Earn 400 pts* for giving your feedback by filling out this "
            )}
            <a className=Style.Link.basic href="http://bit.ly/CommunityRetro" target="_blank">{ReasonReact.string("survey")}</a>
            {ReasonReact.string(".")}
          </p>

          <p> <h4 className=Styles.sidebarHeader> {ReasonReact.string("Challenge #14: 'Leonardo da Coda'")} </h4> </p>
          <p>
            {ReasonReact.string(
              "Bring out your most creative self to create Coda-related GIFs and emoji's! Post your GIF or emoji on the "
            )}
            <a className=Style.Link.basic href="https://forums.codaprotocol.com/t/community-art-contest-leonardo-da-coda/109" target="_blank">{ReasonReact.string("forums")}</a>
            {ReasonReact.string(
              ". You can have unlimited number of entries so cut yourself loose! The community can vote on the best entries by 'hearting' your post, so do not forget to 'heart' your favorite entries! Top 3 entries will receive bonus points: 300 pts* for the best GIF and emoji, 200 pts* for the second place and 100 pts* for the third place."
            )}
          </p>
          <p>
            <em>
              {ReasonReact.string(
                 "* Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points and are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points.",
               )}
            </em>
          </p>
        </div>
      </div>
    </div>;
  },
};
