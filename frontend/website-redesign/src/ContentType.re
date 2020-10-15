// Removes .html from a slug for backwards compatibility
let stripHTMLSuffix = s =>
  switch (String.split_on_char('.', s)) {
  | [] => ""
  | [slug, "html"] => slug
  | [slug, ..._] => slug
  };

module System = {
  type contentType = {id: string};
  type contentTypeSys = {sys: contentType};

  type sys = {
    id: string,
    contentType: contentTypeSys,
    createdAt: string,
    updatedAt: string,
  };

  type includes;

  type entry('a) = {
    sys,
    fields: 'a,
    includes,
  };
  type entries('a) = {
    items: array(entry('a)),
    includes,
  };
};

module Link = {
  type t = {
    linkType: string,
    id: string,
  };

  type entry = {sys: t};
};

module Image = {
  type file = {url: string};
  type t = {file};

  type entry = System.entry(t);
  type entries = System.entries(t);
};

module BlogPost = {
  let id = "test";
  let dateKeyName = "date";
  type t = {
    title: string,
    snippet: string,
    slug: string,
    subtitle: Js.Undefined.t(string),
    author: string,
    authorWebsite: Js.Undefined.t(string),
    date: string,
    text: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module Announcement = {
  let id = "announcement";
  let dateKeyName = "date";
  type t = {
    title: string,
    snippet: string,
    slug: string,
    date: string,
    text: string,
    image: option(Image.entry),
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module JobPost = {
  let id = "jobPost";
  type t = {
    title: string,
    jobDescription: string,
    slug: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module KnowledgeBaseResource = {
  let id = "knowledgeeBaseResource";
  type t = {
    title: string,
    url: string,
    image: Image.entry,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
  [@bs.get]
  external getImages: System.includes => array(Image.entry) = "Asset";
};

module KnowledgeBaseCategory = {
  let id = "knowledgeBaseCategory";
  type t = {
    title: string,
    resources: array(KnowledgeBaseResource.entry),
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module GenesisProfile = {
  let id = "genesisProfile";
  type t = {
    name: string,
    profilePhoto: Image.entry,
    quote: string,
    memberLocation: string,
    twitter: string,
    github: option(string),
    publishDate: string,
    blogPost: BlogPost.entry,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module Press = {
  let id = "press";
  let dateKeyName = "datePublished";
  type t = {
    title: string,
    image: Image.entry,
    link: string,
    featured: bool,
    description: Js.Undefined.t(string),
    publisher: string,
    datePublished: string,
  };
  type entry = System.entry(t);
  type entries = System.entries(t);
};

module NormalizedPressBlog = {
  type t = {
    title: string,
    image: option(Image.entry),
    link: [ | `Slug(string) | `Remote(string)],
    featured: bool,
    description: option(string),
    publisher: option(string),
    date: string,
  };

  let ofBlog = (blog: BlogPost.t) => {
    {
      title: blog.title,
      image: None,
      link: `Slug(blog.slug),
      featured: true,
      description: Some(blog.snippet),
      publisher: Some(blog.author),
      date: blog.date,
    };
  };

  let ofAnnouncement = (announcement: Announcement.t) => {
    {
      title: announcement.title,
      image: announcement.image,
      link: `Slug(announcement.slug),
      featured: true,
      description: Some(announcement.snippet),
      publisher: None,
      date: announcement.date,
    };
  };

  let ofPress = (press: Press.t) => {
    {
      title: press.title,
      image: Some(press.image),
      link: `Remote(press.link),
      featured: press.featured,
      description: Js.Undefined.toOption(press.description),
      publisher: Some(press.publisher),
      date: press.datePublished,
    };
  };

  type entry = System.entry(t);
  type entries = System.entries(t);
};
