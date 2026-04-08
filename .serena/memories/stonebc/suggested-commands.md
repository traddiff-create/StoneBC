# StoneBC Development Commands

## Building & Running
```bash
# Build the iOS app (simulator)
xcodebuild build -scheme StoneBC -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -scheme StoneBC

# Run with code coverage
xcodebuild test -scheme StoneBC -enableCodeCoverage YES

# Clean build
xcodebuild clean -scheme StoneBC

# Open Xcode project
open StoneBC.xcodeproj
```

## Code Quality
```bash
# Format Swift code (using swiftformat if available)
swiftformat --indent 4 StoneBC/

# Lint Swift code (using swiftlint if available)
swiftlint StoneBC/

# Check code coverage report
# After running tests: xcodebuild test -scheme StoneBC -enableCodeCoverage YES
# Open report in: DerivedData/StoneBC/Logs/Test/
```

## Data Processing
```bash
# Convert GPX/FIT route files to JSON
python Scripts/process_routes.py GPX/ > StoneBC/routes.json

# Validate JSON data files
python3 -m json.tool StoneBC/bikes.json
python3 -m json.tool StoneBC/events.json
```

## Git Operations
```bash
# Check status
git status

# View recent commits
git log --oneline -10

# Create a feature branch
git checkout -b feature/description

# Commit changes
git add .
git commit -m "Description of changes"

# Push to remote
git push origin feature/description
```

## Project Navigation
```bash
# List all Swift files in app
find StoneBC -name "*.swift" -type f | sort

# Search for specific patterns
grep -r "WordPressService" StoneBC/

# List JSON data files
ls -lh StoneBC/*.json

# View app configuration
cat StoneBC/config.json | python3 -m json.tool
```

## Testing Checklist
- [ ] Run full test suite: `xcodebuild test -scheme StoneBC`
- [ ] Check code coverage: minimum 70% overall, 80% for ViewModels
- [ ] Verify SwiftUI previews compile
- [ ] Test on iOS 17+ simulator
- [ ] Check for memory leaks (Instruments > Leaks)
- [ ] Test offline mode (with bundle JSON fallback)
- [ ] Verify all images load correctly
- [ ] Check MapKit region calculations
