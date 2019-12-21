module ApplyItem = {
  [@react.component]
  let make = (~filename, ~name) => {
    <li className="list lh-copy">
      <A
        name={"job-" ++ filename}
        href={"/jobs/" ++ filename ++ ".html"}
        className={
          "f5 fw5 no-underline "
          ++ Css.(
               style([
                 color(Style.Colors.hyperlink),
                 hover([color(Style.Colors.hyperlinkHover)]),
               ])
             )
        }>
        {React.string(name)}
      </A>
    </li>;
  };
};

module HeadingItem = {
  [@react.component]
  let make = (~title, ~children) => {
    <div>
      <div className="dn db-ns">
        <div className="flex justify-between mt45">
          <h2 className="pr2 fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
            {React.string(title)}
          </h2>
          <p className="w-65 mt0 mb0 lh-copy"> children </p>
        </div>
      </div>
      <div className="db dn-ns">
        <div className="mt45">
          <h2 className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
            {React.string(title)}
          </h2>
          <p className="mt3 mb0 ml15 lh-copy"> children </p>
        </div>
      </div>
    </div>;
  };
};

let benefits =
  <>
    <div className="flex justify-between ">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0"> {React.string("Healthcare")} </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string(
             {js|We cover 100% of employee premiums for platinum healthcare plans with zero deductible, and 99% of vision and dental\u00A0premiums|js},
           )}
        </li>
      </ul>
    </div>
    <div className="flex justify-between mt4">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0"> {React.string("401k")} </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string("401k contribution matching up to 3% of salary")}
        </li>
      </ul>
    </div>
    <div className="flex justify-between mt4">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0"> {React.string("Education")} </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string(
             {js|$750 annual budget for conferences of your choice (we cover company-related\u00A0conferences)|js},
           )}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("Office library")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("Twice-a-week learning lunches")}
        </li>
      </ul>
    </div>
    <div className="flex justify-between mt4">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0"> {React.string("Equipment")} </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string(
             {js|Top-of-the-line laptop, $500 monitor budget and $500 peripheral\u00A0budget|js},
           )}
        </li>
      </ul>
    </div>
    <div className="flex justify-between mt4">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0">
          {React.string({js|Time\u00A0off|js})}
        </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string(
             {js|Unlimited vacation, with encouragement for employees to take off|js},
           )}
          <span className="i"> {React.string(" at least ")} </span>
          {React.string({js|14 days\u00A0annually|js})}
        </li>
      </ul>
    </div>
    <div className="flex justify-between mt4">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0"> {React.string("Meals")} </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string("Healthy snacks and provided lunch twice a week")}
        </li>
      </ul>
    </div>
    <div className="flex justify-between mt4">
      <div className="flex justify-end w-30">
        <h3 className="fw6 f5 ph4 mt0 mb0"> {React.string("Other")} </h3>
      </div>
      <ul className="mt0 mb0 ph0 w-70">
        <li className="lh-copy list mb0 mt0">
          {React.string("Relocation package")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("Parental leave")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("Commuting benefits")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("Bike-friendly culture")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("Take up to 1 day of PTO per year to volunteer")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("We match nonprofit donations up to $500 per year")}
        </li>
        <li className="lh-copy list mb0 mt0">
          {React.string("...and many others!")}
        </li>
      </ul>
    </div>
  </>;

let str = React.string;

let dot = {
  str({js|·|js});
};

let extraHeaders = () =>
  <>
    <link
      rel="stylesheet"
      type_="text/css"
      href={Links.Cdn.url("/static/css/careers.css")}
    />
    {Head.legacyStylesheets()}
  </>;

[@react.component]
let make = (~jobOpenings) => {
  let jobItems =
    Array.map(
      ((filename, name)) => <ApplyItem key=name filename name />,
      jobOpenings,
    )
    |> React.array;

  let f = Links.Cdn.url;

  <div>
    <div className="mw960 center ph3 ibmplex oceanblack">
      <h1
        className={
          "fadedblue aktivgroteskex careers-double-line-header ttu f5 fw5 tracked-more mb4 nowrap "
          ++ Css.(style([marginTop(`rem(1.25))]))
        }>
        {React.string("Work with us!")}
      </h1>
      <div className=Css.(style([marginBottom(`rem(1.5))]))>
        <div className="dn db-ns">
          <div>
            <div className="careers-gallery-row1">
              <img src={f("/static/img/careers/group-outside.jpg")} />
              <img src={f("/static/img/careers/group-in-house.jpg")} />
            </div>
            <div className="careers-gallery-row2">
              <img src={f("/static/img/careers/nacera-outside.jpg")} />
              <img src={f("/static/img/careers/john-cooking.jpg")} />
              <img src={f("/static/img/careers/vanishree-talking.jpg")} />
            </div>
          </div>
        </div>
        <div className="db dn-ns">
          <img
            className=""
            src={f("/static/img/careers/group-outside.jpg")}
          />
        </div>
      </div>
      <div className="mw800 center">
        <p className="lh-copy f3 ocean f2-ns tracked-tightly">
          {React.string(
             {js|We're using cryptography and cryptocurrency to build computing systems that put people back in control of their digital\u00A0lives.|js},
           )}
        </p>
        <div className="mt45">
          <hr className="mt45 ml0 mr0 mt0 mb0 b0 h2px bg-extradarksnow" />
          <div className="mt45">
            <HeadingItem title="Open Source">
              {React.string(
                 {js|We passionately believe in the open-source philosophy, and make our software free for the entire world to\u00A0use. |js},
               )}
              <A
                name="careers-code"
                href="https://github.com/CodaProtocol/coda"
                className={
                  "fw5 no-underline nowrap "
                  ++ Css.(
                       style([
                         color(Style.Colors.hyperlink),
                         hover([color(Style.Colors.hyperlinkHover)]),
                       ])
                     )
                }>
                {React.string({js|Take a look →|js})}
              </A>
            </HeadingItem>
            <HeadingItem title="Collaboration">
              {React.string(
                 {js|The problems we face are novel and challenging and we take them on as a\u00A0team.|js},
               )}
            </HeadingItem>
            <HeadingItem title="Inclusion">
              {React.string(
                 {js|We're working on technologies with the potential to reimagine social structures. We believe it's important to incorporate diverse perspectives from conception through\u00A0realization.|js},
               )}
            </HeadingItem>
          </div>
        </div>
        <div>
          <hr className="mt45 ml0 mr0 mt0 mb0 b0 h2px bg-extradarksnow" />
          <div>
            <div className="dn db-ns">
              <div className="flex justify-between mt45">
                <h2
                  className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                  {React.string("Benefits")}
                </h2>
                <div className="w-70 mt3"> benefits </div>
              </div>
            </div>
            <div className="db dn-ns">
              <div className="mt45">
                <h2
                  className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                  {React.string("Benefits")}
                </h2>
                <div className="mt4 ml15 mt3"> benefits </div>
              </div>
            </div>
          </div>
        </div>
        <div>
          <hr className="mt45 ml0 mr0 mt0 mb0 b0 h2px bg-extradarksnow" />
          <div>
            <div className="dn db-ns">
              <div className="flex justify-between mt45">
                <div className="w-50">
                  <h2
                    className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                    {React.string("Apply")}
                  </h2>
                </div>
                <div className="w-50">
                  <ul className="mt0 mb0 ph0"> jobItems </ul>
                </div>
              </div>
            </div>
            <div className="db dn-ns">
              <div className="mt45">
                <h2
                  className="fw5 mt0 mb0 ml15 f2 ocean f2-ns tracked-tightly">
                  {React.string("Apply")}
                </h2>
                <ul className="mt4 ml15 mb0 ph0"> jobItems </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>;
};
