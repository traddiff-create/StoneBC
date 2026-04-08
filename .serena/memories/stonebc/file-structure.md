# StoneBC File Structure

## Core App Files
- **StoneBCApp.swift** - App entry point, sets up @Environment for AppState
- **ContentView.swift** - Main container view (likely deprecated in favor of TabContainerView)
- **AppState.swift** - @Observable singleton managing all app state (bikes, events, posts, routes, filters)
- **AppConfig.swift** - Configuration struct loaded from config.json (coalition info, colors, features)
- **TabContainerView.swift** - 5-tab navigation (Home/Routes/Marketplace/Community/More)
- **BCDesignSystem.swift** - Design tokens (colors, fonts, spacing, component styles)

## Views by Feature
### Home/Main
- HomeView.swift - Landing page
- ContactView.swift - Contact form

### Routes
- RoutesView.swift - List of cycling routes with filters
- RouteDetailView.swift - Single route detail with map
- RouteMapView.swift - MapKit-based interactive route visualization

### Marketplace (Bikes)
- MarketplaceView.swift - Bike inventory browsing
- BikeCardRow.swift - Bike card component in grid/list
- BikeDetailView.swift - Single bike details and purchase info
- BikeFilterBar.swift - Status/type filter controls

### Community
- CommunityView.swift - Community hub view
- CommunityFeedView.swift - Feed of posts and events
- PostCardRow.swift - Post card component
- PostDetailView.swift - Single post details
- GalleryView.swift - Photo gallery display

### Open Source Toolkit
- ToolkitArticle.swift - Article layout for toolkit guides

## Data Models
- **Bike.swift** - Bike model + BikeStatus, BikeType, BikeCondition enums
- **Event.swift** - Event model
- **Post.swift** - Post model
- **Route.swift** - Route model with GPS trackpoints
- **Program.swift** - Toolkit article model
- **BCPhoto.swift** - Photo model for gallery

## Data Files (JSON)
- **config.json** - Coalition configuration (name, location, colors, features)
- **bikes.json** - Bike inventory (SBC-### format)
- **events.json** - Upcoming events
- **posts.json** - News/blog posts
- **routes.json** - Cycling routes with GPS data
- **programs.json** - Toolkit articles
- **photos.json** - Gallery photos

## Supporting Directories
- **StoneBC/Toolkit/** - Toolkit image/asset files
- **StoneBC/Thumbnails/** - Photo thumbnail images
- **website/** - Static HTML/CSS/JS for Netlify deployment
- **GPX/** - 42 GPX/FIT route files (raw GPS data)
- **OpenSource-BikeCoopToolkit/** - Documentation for co-op formation
- **business-docs/** - LLC registration, EIN, planning docs
- **Scripts/** - process_routes.py (GPX → JSON converter)

## Project Files
- **StoneBC.xcodeproj/** - Xcode project configuration
- **CLAUDE.md** - This project's Claude notes
- **CHANGELOG.md** - Version history
- **PROJECT.md** - Full roadmap
