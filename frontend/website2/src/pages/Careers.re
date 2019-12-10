module Style = {
  open Css;
  let page = style([maxWidth(`rem(60.)), margin(`auto)]);
  let careersGallery =
    style([
      display(`flex),
      justifyContent(`spaceBetween),
      flexDirection(`column),
      marginBottom(`rem(1.5)),
    ]);
  let galleryRow =
    style([
      selector(
        "*",
        [
          height(`rem(15.)),
          boxSizing(`borderBox),
          padding(`rem(0.3)),
          unsafe("objectFit", "cover"),
        ],
      ),
    ]);

  let text = style([maxWidth(`rem(50.)), margin(`auto)]);
  let h2 =
    merge([
      Theme.H2.basic,
      style([fontWeight(`light), color(Theme.Colors.teal)]),
    ]);
  let heading =
    merge([
      Theme.H2.basic,
      style([
        color(Theme.Colors.teal),
        marginTop(`zero),
        marginBottom(`zero),
      ]),
    ]);
  let hr =
    style([
      height(`px(2)),
      backgroundColor(`hex("E5E9F2")),
      border(`zero, `none, white),
    ]);

  let flexBetween = style([display(`flex), justifyContent(`spaceBetween)]);
  let benefitsListItems =
    style([listStyleType(`none), width(`percent(70.))]);
  let benefitsList =
    merge([
      flexBetween,
      style([
        marginTop(`rem(1.0)),
        width(`percent(70.)),
        flexDirection(`column),
      ]),
    ]);
  let jobListItems = style([listStyleType(`none), width(`percent(50.))]);
};

module HeadingItem = {
  [@react.component]
  let make = (~h2, ~p, ~linkText=?, ~url=?) => {
    <div className=Style.flexBetween>
      <h2 className=Style.heading> {React.string(h2)} </h2>
      <p
        className=Css.(
          merge([
            Theme.Body.basic,
            style([
              width(`percent(65.)),
              marginTop(`zero),
              marginBottom(`zero),
            ]),
          ])
        )>
        {React.string(p)}
        {switch (linkText, url) {
         | (Some(linkText), Some(url)) =>
           <a href=url className=Theme.Link.basic>
             {React.string(" " ++ linkText)}
           </a>
         | _ => React.null
         }}
      </p>
    </div>;
  };
};

module ValuesSection = {
  [@react.component]
  let make = () => {
    <>
      <HeadingItem
        h2="Open Source"
        p="We passionately believe in the open-source philosophy, and make our software free for the entire world to use."
        linkText={js|Take a look →|js}
        url="https://github.com/CodaProtocol/coda"
      />
      <Spacer height=3.5 />
      <HeadingItem
        h2="Collaboration"
        p="The problems we face are nobel and challenging. We take them on as a team."
      />
      <Spacer height=3.5 />
      <HeadingItem
        h2="Inclusion"
        p="We're working on technologies with the potential to reimagine social structures. We believe it's important to incorporate diverse perspectives from conception through realization. "
      />
    </>;
  };
};

module BenefitItem = {
  [@react.component]
  let make = (~title, ~details) => {
    <div
      className=Css.(
        merge([Style.flexBetween, style([marginBottom(`rem(1.5))])])
      )>
      <h3
        className=Css.(
          merge([
            Theme.H3.basic,
            style([
              color(Theme.Colors.saville),
              marginTop(`zero),
              marginBottom(`zero),
              width(`percent(30.)),
              fontSize(`rem(1.)),
              textAlign(`right),
              paddingRight(`rem(2.)),
            ]),
          ])
        )>
        {React.string(title)}
      </h3>
      <ul className=Style.benefitsListItems>
        {React.array(
           Array.map(
             item =>
               <li
                 className=Css.(
                   merge([
                     Theme.Body.basic,
                     style([marginTop(`zero), marginBottom(`zero)]),
                   ])
                 )>
                 {React.string(item)}
               </li>,
             details,
           ),
         )}
      </ul>
    </div>;
  };
};
module BenefitsSection = {
  [@react.component]
  let make = () => {
    <div className=Style.flexBetween>
      <h2 className=Style.heading> {React.string("Benefits")} </h2>
      <div className=Style.benefitsList>
        <BenefitItem
          title="Healthcare"
          details=[|
            "We cover 100% of employee premiums for platinum healthcare plans with zero deductible, and 99% of vision and dental premiums",
          |]
        />
        <BenefitItem
          title="401k"
          details=[|"401k contribution matching up to 3% of salary"|]
        />
        <BenefitItem
          title="Education"
          details=[|
            "$750 annual budget for conferences of your choice (we cover company-related conferences)",
            "Office library",
            "Twice-a-week learning lunches",
          |]
        />
        <BenefitItem
          title="Equipment"
          details=[|
            "Top-of-the-line laptop, $500 monitor budget and $500 peripheral budget",
          |]
        />
        <BenefitItem
          title="Time off"
          details=[|
            "Unlimited vacation, with encouragement for employees to take off at least 14 days annually",
          |]
        />
        <BenefitItem
          title="Meals"
          details=[|"Healthy snacks and provided lunch twice a week"|]
        />
        <BenefitItem
          title="Other"
          details=[|
            "Relocation package",
            "Parental leave",
            "Commuting benefits",
            "Bike-friendly culture",
            "Take up to 1 day of PTO per year to volunteer",
            "We match nonprofit donations up to $500 per year",
            "...and many others!",
          |]
        />
      </div>
    </div>;
  };
};

module ApplySection = {
  [@react.component]
  let make = () => {
    <div className=Style.flexBetween>
      <h2
        className=Css.(
          merge([Style.heading, style([width(`percent(50.))])])
        )>
        {React.string("Apply")}
      </h2>
      <ul className=Style.jobListItems>
        <li>
          <a
            href="https://codaprotocol.com/jobs/engineering-manager.html"
            className=Theme.Link.basic>
            {React.string("Engineering Manager (San Francisco)")}
          </a>
        </li>
      </ul>
    </div>;
  };
};

[@react.component]
let make = () => {
  <Page>
    <div className=Style.page>
      <h1 className=Theme.H3.wings> {React.string("Work with us!")} </h1>
      <Spacer height=2.0 />
      <div className=Style.careersGallery>
        <div className=Style.galleryRow>
          <img
            src="/static/img/careers/group-outside.jpg"
            className=Css.(style([width(`percent(35.))]))
          />
          <img
            src="/static/img/careers/group-in-house.jpg"
            className=Css.(style([width(`percent(65.))]))
          />
        </div>
        <div className=Style.galleryRow>
          <img
            src="/static/img/careers/nacera-outside.jpg"
            className=Css.(style([width(`percent(30.))]))
          />
          <img
            src="/static/img/careers/john-cooking.jpg"
            className=Css.(style([width(`percent(37.))]))
          />
          <img
            src="/static/img/careers/vanishree-talking.jpg"
            className=Css.(style([width(`percent(33.))]))
          />
        </div>
      </div>
      <div className=Style.text>
        <h1 className=Style.h2>
          {React.string(
             {js|We're using cryptography and cryptocurrency to build computing systems that put people back in control of their digital\u00A0lives.|js},
           )}
        </h1>
        <Spacer height=3.5 />
        <hr className=Style.hr />
        <Spacer height=3.5 />
        <ValuesSection />
        <Spacer height=3.5 />
        <hr className=Style.hr />
        <Spacer height=3.5 />
        <BenefitsSection />
        <Spacer height=3.5 />
        <hr className=Style.hr />
        <Spacer height=3.5 />
        <ApplySection />
        <Spacer height=3.5 />
      </div>
    </div>
  </Page>;
};
