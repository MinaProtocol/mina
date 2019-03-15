let component = ReasonReact.statelessComponent("Nav");
let make = children => {
  ...component,
  render: _self =>
    <div
      className="flex items-center mw9 mb5-m mb4 ph6-l ph5-m ph4 mw9-l mt3 mt4-m mt5-l center">
      <div className="w-50">
        <a href="/" name="navbar-coda-home" className="hover-link">
          <div>
            <div className="dn db-ns">
              <div>
                <img width="220px" src="/static/img/logo.svg" className="" />
              </div>
            </div>
            <div className="db dn-ns">
              <div className="flex justify-center">
                <img width="220px" src="/static/img/logo.svg" className="" />
              </div>
            </div>
          </div>
        </a>
      </div>
      <div className="flex justify-around w-75">
        <a
          href="/blog/index.html"
          name="navbar-blog"
          className="fw3 silver tracked ttu dn db-ns no-underline hover-link">
          {ReasonReact.string("Blog")}
        </a>
        <a
          href="/testnet.html"
          name="navbar-testnet"
          className="fw3 silver tracked ttu no-underline hover-link">
          {ReasonReact.string("Testnet")}
        </a>
        <a
          href="/code.html"
          name="navbar-code"
          className="fw3 silver tracked ttu no-underline hover-link">
          {ReasonReact.string("Code")}
        </a>
        <a
          href="/jobs.html"
          name="navbar-jobs"
          className="fw3 silver tracked ttu no-underline hover-link">
          {ReasonReact.string("Jobs")}
        </a>
        <a
          href="https://goo.gl/forms/PTusW11oYpLKJrZH3"
          name="navbar-sign-up"
          className="fw3 silver tracked ttu dn db-l no-underline hover-link"
          target="_blank">
          {ReasonReact.string("Sign up")}
        </a>
      </div>
    </div>,
};
