module.exports = function (eleventyConfig) {
  // Pass through static assets unchanged
  eleventyConfig.addPassthroughCopy("src/css");
  eleventyConfig.addPassthroughCopy("src/js");
  eleventyConfig.addPassthroughCopy("src/images");

  // Pass through static HTML pages that aren't templated yet
  eleventyConfig.addPassthroughCopy("src/index.html");
  eleventyConfig.addPassthroughCopy("src/about.html");
  eleventyConfig.addPassthroughCopy("src/programs.html");
  eleventyConfig.addPassthroughCopy("src/quarry.html");
  eleventyConfig.addPassthroughCopy("src/routes.html");
  eleventyConfig.addPassthroughCopy("src/contact.html");
  eleventyConfig.addPassthroughCopy("src/donate.html");
  eleventyConfig.addPassthroughCopy("src/404.html");

  // Date formatting filter
  eleventyConfig.addFilter("dateDisplay", (dateStr) => {
    if (!dateStr) return "";
    const date = new Date(dateStr);
    if (isNaN(date)) return dateStr;
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "long",
      day: "numeric",
    });
  });

  // Month abbreviation filter
  eleventyConfig.addFilter("monthAbbr", (dateStr) => {
    if (!dateStr) return "";
    const date = new Date(dateStr);
    if (isNaN(date)) return dateStr.substring(0, 3).toUpperCase();
    return date
      .toLocaleDateString("en-US", { month: "short" })
      .toUpperCase();
  });

  // Day number filter
  eleventyConfig.addFilter("dayNum", (dateStr) => {
    if (!dateStr) return "";
    const date = new Date(dateStr);
    if (isNaN(date)) return "";
    return date.getDate().toString().padStart(2, "0");
  });

  // Strip HTML tags filter
  eleventyConfig.addFilter("stripHTML", (str) => {
    if (!str) return "";
    return str
      .replace(/<[^>]+>/g, "")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&nbsp;/g, " ")
      .trim();
  });

  // Truncate filter
  eleventyConfig.addFilter("truncate", (str, len = 150) => {
    if (!str) return "";
    if (str.length <= len) return str;
    return str.substring(0, len).replace(/\s+\S*$/, "") + "...";
  });

  return {
    dir: {
      input: "src",
      output: "_site",
      includes: "_includes",
      data: "_data",
    },
    templateFormats: ["njk", "html", "md"],
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk",
  };
};
