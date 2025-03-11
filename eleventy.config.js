module.exports = function (eleventyConfig) {
  // Copy any JS and CSS filers through to the build.
  eleventyConfig.addPassthroughCopy("**/*.css");
  eleventyConfig.addPassthroughCopy("**/*.js");
};
