# Task Completion Checklist for StoneBC

## After Making Code Changes

### Code Quality
- [ ] Code follows established style guide (KISS, DRY, YAGNI, immutability first)
- [ ] No force unwrapping (!) used inappropriately
- [ ] Proper error handling with do/catch
- [ ] Async/await used for concurrent operations
- [ ] @Observable used for view models, @State for local state
- [ ] Access modifiers explicitly set (public, private, etc.)

### Testing
- [ ] Unit tests written for new ViewModels/Services
- [ ] ViewModels tested at 80%+ coverage (target 90%)
- [ ] Services tested at 75%+ coverage (target 85%)
- [ ] Happy path, error cases, edge cases covered
- [ ] Tests follow arrange-act-assert pattern
- [ ] Protocol-based mocks used for dependencies

### Documentation
- [ ] Public APIs documented with /// markdown comments
- [ ] Complex logic commented with WHY, not WHAT
- [ ] Function signatures include parameter descriptions
- [ ] README updated if feature affects user workflow

### Integration
- [ ] Changes integrated with AppState (if affecting app-wide state)
- [ ] Configuration changes added to config.json if needed
- [ ] Data model changes reflected in JSON test files
- [ ] SwiftUI previews updated/tested

### Before Committing
- [ ] Run `xcodebuild test -scheme StoneBC`
- [ ] Verify no compiler warnings
- [ ] Check code coverage hasn't decreased
- [ ] Run linter (swiftlint) if available
- [ ] Verify SwiftUI previews render correctly
- [ ] Test on iOS 17+ simulator

### Git Workflow
1. Create feature branch: `git checkout -b feature/description`
2. Make changes and test thoroughly
3. Commit with clear message: `git commit -m "Add [Feature]: description"`
4. Push to remote: `git push origin feature/description`
5. Create pull request with summary of changes

### Documentation Updates (if applicable)
- Update CHANGELOG.md with new features
- Update PROJECT.md roadmap if status changes
- Update CLAUDE.md if architecture changes significantly
