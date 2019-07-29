module Styles = {
  open! Css;

  let markdownStyles = linkSvg =>
    style([
      position(`relative),
      selector(
        "h1, h2, h3, h4",
        [
          display(`flex),
          marginTop(rem(2.)),
          marginBottom(`rem(0.5)),
          color(Style.Colors.denimTwo),
          hover([selector(".headerlink", [display(`inlineBlock)])]),
        ],
      ),
      selector(
        ".headerlink",
        [
          display(`none),
          width(rem(1.)),
          height(rem(1.)),
          marginLeft(rem(0.5)),
          color(`transparent),
          hover([color(`transparent)]),
          backgroundSize(`cover),
          backgroundImage(url(linkSvg)),
        ],
      ),
      selector(
        "h1",
        Style.H1.heroStyles @ [alignItems(`baseline), fontWeight(`normal)],
      ),
      selector("h2", Style.H2.basicStyles @ [alignItems(`baseline)]),
      selector(
        "h3",
        Style.H3.basicStyles
        @ [textAlign(`left), alignItems(`center), fontWeight(`medium)],
      ),
      selector(
        "h4",
        Style.H4.basicStyles @ [textAlign(`left), alignItems(`center)],
      ),
      selector("p", Style.Body.basicStyles),
      selector(
        "ul, ol",
        [
          margin2(~v=`rem(1.), ~h=`zero),
          marginLeft(rem(1.5)),
          padding(`zero),
          ...Style.Body.basicStyles,
        ],
      ),
      selector(
        "code",
        [Style.Typeface.pragmataPro, color(Style.Colors.midnight)],
      ),
      selector(
        "p > code, li > code",
        [
          boxSizing(`borderBox),
          padding2(~v=`px(2), ~h=`px(6)),
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(4)),
        ],
      ),
      selector(
        "pre",
        [
          backgroundColor(Style.Colors.slateAlpha(0.05)),
          borderRadius(`px(9)),
          padding2(~v=`rem(0.5), ~h=`rem(1.)),
          overflow(`scroll),
        ],
      ),
      selector(
        "a",
        [
          hover([color(Style.Colors.hyperlinkHover)]),
          cursor(`pointer),
          ...Style.Link.basicStyles,
        ],
      ),
      selector(
        "strong",
        [fontWeight(`num(600)), color(Style.Colors.metallicBlue)],
      ),
      selector(
        ".admonition",
        [
          border(px(1), `solid, `currentColor),
          borderRadius(px(9)),
          overflow(`hidden),
          selector(
            "p",
            [margin(`zero), padding2(~v=`rem(0.5), ~h=`rem(1.))],
          ),
          selector(".admonition-title", [fontWeight(`num(600))]),
        ],
      ),
      selector(
        ".admonition.note",
        [
          color(Style.Colors.marineAlpha(0.8)),
          selector(
            ".admonition-title",
            [color(white), backgroundColor(Style.Colors.marineAlpha(0.8))],
          ),
        ],
      ),
      selector(
        ".admonition.warning",
        [
          color(Style.Colors.rosebudAlpha(0.8)),
          selector(
            ".admonition-title",
            [
              color(white),
              backgroundColor(Style.Colors.rosebudAlpha(0.8)),
            ],
          ),
        ],
      ),
    ]);

  let sideNav =
    style([
      minWidth(rem(15.)),
      selector("ul", [listStyleType(`none)]),
      selector("ul:first-child", [marginLeft(`zero)]),
      selector("li > ul", [marginLeft(rem(1.))]),
      selector("li", [marginBottom(rem(0.5))]),
      selector(
        ".current > a",
        [
          position(`relative),
          fontWeight(`bold),
          before([
            position(`absolute),
            left(rem(-0.75)),
            contentRule("\\2022 "),
          ]),
        ],
      ),
      selector("ul > li > ul", [marginTop(rem(0.5))]),
      selector("input ~ ul", [display(`none)]),
      selector("input:checked ~ ul", [display(`block)]),
      selector(
        "li > label",
        [
          display(`flex),
          alignItems(`center),
          justifyContent(`spaceBetween),
        ],
      ),
      selector(
        "label > img",
        [opacity(0.7), transform(rotate(`deg(0)))],
      ),
      selector(
        "input:checked ~ label > img",
        [transform(rotate(`deg(-180)))],
      ),
      media(
        Style.MediaQuery.somewhatLarge,
        [marginRight(rem(2.)), marginTop(rem(3.))],
      ),
    ]);
};

let component = ReasonReact.statelessComponent("Blog");

let make = _children => {
  ...component,
  render: _self => {
    // We need to calculate the CDN url and inject it into the template
    let chevronUrl = Links.Cdn.url("/static/img/chevron-down.svg");
    let linkUrl = Links.Cdn.url("/static/img/link.svg");
    <div
      className=Css.(
        merge([
          Styles.markdownStyles(linkUrl),
          style([
            display(`flex),
            flexDirection(`column),
            alignItems(`flexStart),
            justifyContent(`center),
            marginLeft(`auto),
            marginRight(`auto),
            media(Style.MediaQuery.full, [marginTop(`rem(2.0))]),
            media(Style.MediaQuery.somewhatLarge, [flexDirection(`row)]),
          ]),
        ])
      )>
      <aside
        className=Styles.sideNav
        dangerouslySetInnerHTML={
          "__html": {j|
            {% if nav|length>1 %}
              <ul>
              {% for nav_item in nav %}
                {% if nav_item.children %}
                  <li>
                    <input
                      type="checkbox"
                      {% if nav_item.children|map(attribute='active')|sort|last %}
                        checked
                      {% endif %}
                      style="display:none"
                      id="{{nav_item.title|replace(" ", "_") }}-toggle"
                    />
                    <label for="{{nav_item.title|replace(" ", "_") }}-toggle" style="cursor:pointer">
                      {{ nav_item.title }}
                      <img src="$chevronUrl" width="16" height="16" />
                    </label>
                    <ul>
                    {% for nav_item in nav_item.children %}
                      <li class="{% if nav_item.active%}current{% endif %}">
                        <a href="{{ nav_item.url|url }}">{{ nav_item.title }}</a>
                      </li>
                    {% endfor %}
                    </ul>
                  </li>
                {% else %}
                  <li class="{% if nav_item.active%}current{% endif %}">
                    <a href="{{ nav_item.url|url }}">{{ nav_item.title }}</a>
                  </li>
                {% endif %}
              {% endfor %}
              </ul>
            {% endif %}
          |j},
        }
      />
      <article
        className=Css.(
          style([maxWidth(`rem(43.)), width(`percent(100.))])
        )>
        <A
          name="Edit Link"
          target="_blank"
          href="{{ page.edit_url }}"
          className=Css.(
            style([
              position(`relative),
              float(`right),
              display(`flex),
              alignItems(`center),
              marginTop(`rem(3.25)),
              marginBottom(`rem(0.5)),
              hover([color(Style.Colors.hyperlinkHover)]),
              ...Style.Link.basicStyles,
            ])
          )>
          <svg
            fill="currentColor"
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24">
            <path
              d="M7.127 22.562l-7.127 1.438 1.438-7.128 5.689 5.69zm1.414-1.414l11.228-11.225-5.69-5.692-11.227 11.227 5.689 5.69zm9.768-21.148l-2.816 2.817 5.691 5.691 2.816-2.819-5.691-5.689z"
            />
          </svg>
          <span className=Css.(style([marginLeft(`rem(0.25))]))>
            {ReasonReact.string("Edit")}
          </span>
        </A>
        {ReasonReact.string("{{ page.content }}")}
        <hr
          className=Css.(
            style([
              borderColor(Style.Colors.slateAlpha(0.1)),
              margin2(~v=`rem(2.), ~h=`zero),
            ])
          )
        />
        <div
          className=Css.(
            style([display(`flex), justifyContent(`spaceBetween)])
          )>
          {ReasonReact.string("{% if page.previous_page %}")}
          <A name="next_page" href="{{ page.previous_page.url|url }}">
            {ReasonReact.string({js|⟵ {{ page.previous_page.title }}|js})}
          </A>
          {ReasonReact.string("{% else %}")}
          <span />
          {ReasonReact.string("{% endif %}")}
          {ReasonReact.string("{% if page.next_page %}")}
          <A name="next_page" href="{{ page.next_page.url|url }}">
            {ReasonReact.string({js|{{ page.next_page.title }} ⟶|js})}
          </A>
          {ReasonReact.string("{% else %}")}
          <span />
          {ReasonReact.string("{% endif %}")}
        </div>
      </article>
      <script src={Links.Cdn.url("/static/js/clipboard.js")} />
    </div>;
  },
};
