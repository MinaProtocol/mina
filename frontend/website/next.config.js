const path = require('path');

const { createClient } = require('contentful');

const withMDX = require('@next/mdx')({
  options: {
    remarkPlugins: [require('remark-slug')],
    rehypePlugins: [[require('rehype-highlight'), {subset: false}]],
  } });

const withTM = require('next-transpile-modules');

const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

const SPACE = process.env.CONTENTFUL_SPACE || '37811siqosrn';
const TOKEN = process.env.CONTENTFUL_TOKEN || 'gONaARVCc0G5FLIkoJ2m4qi9yTpT8oi7u-C6VYxQ6UQ';
const IMAGE_TOKEN = process.env.CONTENTFUL_IMAGE_TOKEN || "3B4LS4VD0c4RCsUl1rxmmX/d8ba4bd5295e3b65569cbda1329e90a6";
const CONTENTFUL_HOST = process.env.CONTENTFUL_HOST || "cdn.contentful.com";
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY || 'AIzaSyDIFwMr7SPGCLl_o6e4UZKi1q9l8snkUZs';

const blogType = 'test';
const client = createClient({ accessToken: TOKEN, space: SPACE, host: CONTENTFUL_HOST });

module.exports = withTM(withBundleAnalyzer(withMDX({
  async exportPathMap(pages) {
    let blogPosts = await client.getEntries({ include: 0, content_type: blogType });
    let jobPosts = await client.getEntries({
      include: 0, content_type: 'jobPost'
    });

    // Add versions with trailing slash for backwards compatibility
    pages['/blog/'] = { page: '/blog'}
    pages['/jobs/'] = { page: '/jobs'}

    blogPosts.items.forEach(
      ({ fields: { slug } }) => {
        pages['/blog/' + slug] = { page: '/blog/[slug]', query: { slug: slug } }
        // Add .html for backwards compatibility
        pages['/blog/' + slug + ".html"] = { page: '/blog/[slug]', query: { slug: slug } }
      });

    jobPosts.items.forEach(
      ({ fields: { slug } }) => {
        pages['/jobs/' + slug] = { page: '/jobs/[slug]', query: { slug: slug } }
        // Add .html for backwards compatibility
        pages['/jobs/' + slug + ".html"] = { page: '/jobs/[slug]', query: { slug: slug } }
      });

    return pages;
  },
  pageExtensions: ['jsx', 'js', 'mdx', 'bs.js'],
  transpileModules: ['bs-platform', 'bs-css', 'bsc-stdlib-polyfill', 'bs-fetch'],
  webpack(config, options) {
    config.resolve.alias['@reason'] = path.resolve(__dirname, 'lib', 'es6', 'src');
    config.resolve.extensions.push('.bs.js');
    return config
  },
  env: {
    CONTENTFUL_TOKEN: TOKEN,
    CONTENTFUL_IMAGE_TOKEN: IMAGE_TOKEN,
    CONTENTFUL_SPACE: SPACE,
    CONTENTFUL_HOST: CONTENTFUL_HOST,
    GOOGLE_API_KEY: GOOGLE_API_KEY,
  }
})))
