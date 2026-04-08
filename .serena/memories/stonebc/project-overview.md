# StoneBC Project Overview

## Purpose
Stone Bicycle Coalition is a community bike co-op iOS app with three components:
1. **iOS App** - Native Swift/SwiftUI info app for cycling routes, events, marketplace, and community
2. **Website** - Static Netlify site (stonebicyclecoalition.com) 
3. **Open-Source Toolkit** - Replicable guide for starting bike cooperatives (CC BY-SA 4.0)

## Status
- **Version**: 0.1 (maintenance/testing phase)
- **Bundle ID**: com.traddiff.StoneBC
- **Business**: LLC (DL308353, EIN 39-4226443), transitioning to 501(c)(3) nonprofit

## Current Architecture
- **iOS App**: 27 Swift files + 5 JSON data files (bundles all data locally)
- **Data-driven**: Models load from JSON bundles (bikes.json, events.json, posts.json, routes.json, programs.json, photos.json)
- **SwiftUI + MapKit**: Modern iOS UI with interactive map for routes
- **@Observable Pattern**: AppState manages all app-wide state using Observation framework
- **MVVM Design**: Separation of views, view models, and services

## Key Models
- **Bike**: SBC-### IDs, status (available/refurbishing/sponsored/sold), type (road/hybrid/mountain/cargo/cruiser), condition, features, sponsorPrice
- **Event**: title, date, location, category (ride/workshop/openShop/social), isRecurring
- **Post**: title, body, imageURL, date, category (featured/news/event/announcement)
- **Route**: id, name, difficulty (easy/moderate/hard/expert), category (road/gravel/fatbike/trail), distance/elevation, GPS trackpoints from GPX/FIT files
- **Program**: toolkit articles (Earn-A-Bike, Safety Training, Youth Programs, etc.)

## Core Dependencies
- Swift 5.1+
- SwiftUI (iOS 17+)
- MapKit for route visualization
- CoreLocation for GPS tracking
- Observation framework for @Observable state management
