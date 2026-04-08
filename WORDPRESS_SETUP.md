# WordPress Headless CMS Setup Guide

This guide sets up WordPress as a headless CMS for the Stone Bicycle Coalition app (or your own bike co-op fork). WordPress manages events, bikes, and blog posts — the iOS app and website pull content via the REST API.

## 1. WordPress Installation

**Option A: WordPress.com Business** ($300/yr)
- Includes plugins, custom themes, SFTP
- Managed hosting, SSL, backups included

**Option B: Self-hosted** (~$15-25/mo)
- SiteGround, Cloudways, or similar
- Install WordPress via one-click installer
- Set up SSL certificate

## 2. Required Plugins

Install and activate these plugins:

| Plugin | Purpose |
|--------|---------|
| **Custom Post Type UI** | Register `sbc_event` and `sbc_bike` post types |
| **Advanced Custom Fields** | Custom fields for events and bikes |
| **ACF to REST API** | Exposes ACF fields in WP REST API responses |

## 3. Custom Post Types

### Create via Custom Post Type UI

**Post Type: `sbc_event`**
- Plural: Events
- Singular: Event
- Show in REST API: Yes
- REST API base slug: `sbc_event`

**Post Type: `sbc_bike`**
- Plural: Bikes
- Singular: Bike
- Show in REST API: Yes
- REST API base slug: `sbc_bike`

## 4. ACF Field Groups

### Field Group: "Bike Details" (for `sbc_bike`)

| Field Name | Field Type | Choices |
|------------|-----------|---------|
| `bike_id` | Text | — |
| `bike_status` | Select | available, refurbishing, sponsored, sold |
| `bike_type` | Select | road, hybrid, mountain, cargo, cruiser |
| `frame_size` | Text | — |
| `wheel_size` | Text | — |
| `bike_color` | Text | — |
| `condition` | Select | excellent, good, fair, poor |
| `sponsor_price` | Number | — |
| `acquired_via` | Select | donation, purchase, trade |
| `date_added` | Date Picker | Return format: Y-m-d |

**Location rule:** Post Type is equal to Bike

### Field Group: "Event Details" (for `sbc_event`)

| Field Name | Field Type | Choices |
|------------|-----------|---------|
| `event_date` | Text | — |
| `event_time` | Text | — |
| `event_location` | Text | — |
| `event_category` | Select | ride, workshop, social, openShop |
| `is_recurring` | True / False | — |

**Location rule:** Post Type is equal to Event

## 5. API Verification

After setup, verify the API returns data:

```bash
# List all bikes
curl https://your-site.com/wp-json/wp/v2/sbc_bike?per_page=5

# List all events
curl https://your-site.com/wp-json/wp/v2/sbc_event?per_page=5

# List blog posts
curl https://your-site.com/wp-json/wp/v2/posts?per_page=5
```

Each response should include an `acf` object with your custom fields.

## 6. App Configuration

Update `StoneBC/config.json` with your WordPress URL:

```json
{
  "dataURLs": {
    "wordpressBase": "https://your-site.com/wp-json/wp/v2",
    "bikes": "/sbc_bike?per_page=50",
    "events": "/sbc_event?per_page=50",
    "posts": "/posts?per_page=20&_embed"
  }
}
```

Set `wordpressBase` to `null` to disable remote sync (app uses bundled JSON only).

## 7. Data Migration

If migrating from bundled JSON files:

```bash
pip install requests

export WP_URL="https://your-site.com"
export WP_USER="admin"
export WP_APP_PASSWORD="xxxx xxxx xxxx xxxx"

python3 Scripts/migrate_to_wordpress.py
```

Generate an Application Password in WP Admin > Users > Your Profile > Application Passwords.

## 8. Website Integration (Optional)

To have your Netlify site pull from WordPress at build time:

1. Create a Netlify Build Hook (Site Settings > Build & Deploy > Build Hooks)
2. Install a WordPress webhook plugin (e.g., WP Webhooks)
3. Configure: On "Post Published" > POST to Netlify build hook URL
4. Site rebuilds automatically when content changes in WordPress

## How It Works

```
WordPress Admin (Nicole/Rory create content)
    ↓
WP REST API (/wp-json/wp/v2/...)
    ↓                    ↓
iOS App (background    Netlify Site
sync on launch)        (build-time fetch)
    ↓                    ↓
Users see fresh        Visitors see fresh
content in app         content on website
```

The iOS app always loads bundled JSON first (works offline), then syncs from WordPress in the background. If WordPress is unreachable, the app works normally with bundled data.
