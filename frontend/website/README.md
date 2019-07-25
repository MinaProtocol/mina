## How to build the website

**Setup:**
1. Clone the repo via SSH: `git clone git@github.com:CodaProtocol/coda.git`
2. Navigate into `coda/frontend/website`
3. Run `yarn` to install dependencies (alternatively `npm install`)
4. Install [pandoc](https://pandoc.org/) via `brew install pandoc` or similar.
5. Install [mkdocs](https://mkdocs.org) via `pip install mkdocs` or similar.

**Develop:**

1. Run `yarn dev` to build (with a watcher) and start a server (alternatively `npm run dev`)
2. Open `localhost:8000` in your browser to see the site. You can edit files in `src` and save to see changes.

**Deploy:**

1. Make sure you have the latest `master` branch and that code is stable.
2. If you've changed any static assets, first run `./deploy-cdn.sh` - this will update the S3 bucket with latest assets.
3. Run `./deploy-website.sh staging` and make sure that the staging build is stable (visit https://proof-of-steak-7ab54.firebaseapp.com/).
4. Run `./deploy-website.sh prod`.

- NOTE: this will require Firebase and AWS credentials


### To create a new blog post
1. Follow the build instructions above
2. Create a new markdown file in `coda/frontend/website/posts`. You can use the other files in that folder as an example. It should start with something like this:

```
---
title: My blog post
subtitle: This is what my blog post is about (optional)
date: 2019-01-01
author: My Name
author_website: https://twitter.com/my_twitter_username (optional)
---
```

3. Leave `yarn dev` running as you edit and save your post to make `localhost:8000` reload.
