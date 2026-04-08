/**
 * WordPress data fetcher for Eleventy
 *
 * Fetches events, bikes, and posts from WordPress REST API at build time.
 * Falls back to empty arrays if WordPress is unreachable.
 *
 * Set WP_API_URL environment variable to your WordPress base URL:
 *   WP_API_URL=https://stonebikeco.com npx @11ty/eleventy
 */

const WP_BASE = process.env.WP_API_URL
  ? `${process.env.WP_API_URL.replace(/\/$/, "")}/wp-json/wp/v2`
  : null;

async function fetchWP(endpoint) {
  if (!WP_BASE) {
    console.log(`[wp] No WP_API_URL set, skipping: ${endpoint}`);
    return [];
  }

  const url = `${WP_BASE}${endpoint}`;
  console.log(`[wp] Fetching: ${url}`);

  try {
    const resp = await fetch(url);
    if (!resp.ok) {
      console.warn(`[wp] ${resp.status} from ${url}`);
      return [];
    }
    return await resp.json();
  } catch (err) {
    console.warn(`[wp] Failed to fetch ${url}: ${err.message}`);
    return [];
  }
}

function stripHTML(str) {
  if (!str) return "";
  return str
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#8217;/g, "'")
    .replace(/&#8220;/g, '"')
    .replace(/&#8221;/g, '"')
    .replace(/&nbsp;/g, " ")
    .trim();
}

module.exports = async function () {
  const [wpEvents, wpBikes, wpPosts] = await Promise.all([
    fetchWP("/sbc_event?per_page=50"),
    fetchWP("/sbc_bike?per_page=50"),
    fetchWP("/posts?per_page=20&_embed"),
  ]);

  const events = wpEvents.map((e) => ({
    id: `wp-${e.id}`,
    title: stripHTML(e.title?.rendered),
    description: stripHTML(e.content?.rendered),
    date: e.acf?.event_date || "",
    time: e.acf?.event_time || "",
    location: e.acf?.event_location || "",
    category: e.acf?.event_category || "social",
    isRecurring: e.acf?.is_recurring || false,
  }));

  const bikes = wpBikes.map((b) => ({
    id: b.acf?.bike_id || `SBC-${b.id}`,
    title: stripHTML(b.title?.rendered),
    description: stripHTML(b.content?.rendered),
    status: b.acf?.bike_status || "available",
    type: b.acf?.bike_type || "hybrid",
    frameSize: b.acf?.frame_size || "",
    wheelSize: b.acf?.wheel_size || "",
    color: b.acf?.bike_color || "",
    condition: b.acf?.condition || "good",
    sponsorPrice: b.acf?.sponsor_price || 0,
    acquiredVia: b.acf?.acquired_via || "donation",
  }));

  const posts = wpPosts.map((p) => ({
    id: `wp-${p.id}`,
    title: stripHTML(p.title?.rendered),
    content: p.content?.rendered || "",
    excerpt: stripHTML(p.excerpt?.rendered),
    date: p.date ? p.date.substring(0, 10) : "",
    slug: p.slug || "",
  }));

  console.log(
    `[wp] Loaded: ${events.length} events, ${bikes.length} bikes, ${posts.length} posts`
  );

  return { events, bikes, posts };
};
