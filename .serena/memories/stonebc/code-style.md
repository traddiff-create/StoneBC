# StoneBC Code Style & Conventions

## Swift Coding Standards
Follows Rory Stone's established style guidelines:

### Immutability First
- Prefer `let` over `var` whenever possible
- Use computed properties for derived values
- Create new collections instead of mutating: `let newItems = items + [4]`

### Naming Conventions
- **Types**: PascalCase (Bike, AppState, BCDesignSystem)
- **Properties/Variables**: camelCase (selectedBikeStatus, filteredBikes)
- **Functions**: camelCase, verb-noun pattern (loadData, bikeCount, formatPrice)
- **Constants**: camelCase or SCREAMING_SNAKE (API_VERSION, defaultTimeout)

### Error Handling
- Comprehensive error handling with proper do/catch blocks
- Avoid force unwrapping (!) - use guard let or optional chaining
- Return meaningful error types instead of silencing errors with try?

### Async/Await
- Use async/await instead of callbacks
- Parallel execution with async let when operations are independent
- Always check Task.isCancelled in long operations

### Access Control
- Explicit access modifiers (public, private, fileprivate)
- Prefer private(set) for read-only external properties
- Internal details marked as private

## SwiftUI Patterns
- Extract large views into smaller components (max ~300 lines per view)
- Use @Observable for view models (not @StateObject/@ObservedObject)
- Use @State for local view state only
- Use @Environment for app-wide state (AppState)
- Extract computed UI sections into separate properties (headerSection, contentSection, etc.)

## File Organization
- One primary type per file (Bike.swift, Event.swift, Post.swift)
- Related enums grouped in same file as primary type
- Extensions grouped by functionality
- Mark sections with MARK: comments

## JSON Loading
- Models have static `loadFromBundle()` methods that decode from embedded JSON files
- Use Codable protocol for all data models
- Handle missing/invalid JSON gracefully with fallback defaults

## Comments & Documentation
- Explain WHY not WHAT
- Public APIs documented with /// markdown comments
- Include parameter descriptions and example usage for complex functions
- Self-documenting code preferred over verbose comments
