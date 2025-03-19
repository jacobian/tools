module.exports = function (eleventyConfig) {
  // Copy any JS and CSS filers through to the build.
  eleventyConfig.addPassthroughCopy("**/*.css");
  eleventyConfig.addPassthroughCopy("**/*.js");
  eleventyConfig.setServerOptions({
    // liveReload doesn't seem to be working with Tailwind so turn it off.
    liveReload: false,
  });
};
