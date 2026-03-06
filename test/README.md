# Test Directory Structure

This directory contains comprehensive tests for the Pager library, organized by API version and functionality.

## Directory Structure

```
test/
├── README.md                  # This file - test documentation
├── dual_api_test.dart        # Tests for dual API access functionality
├── legacy/                   # Legacy API (deprecated) tests
│   ├── pager_basic_test.dart    # Basic legacy pager functionality
│   └── pager_sorting_test.dart  # Legacy pager sorting functionality
└── paging3/                  # Paging3 API (current) tests
    ├── load_state_test.dart     # Load state management tests
    ├── pager_test.dart          # Core pager functionality tests  
    ├── paging_data_test.dart    # PagingData container tests
    └── paging_source_test.dart  # PagingSource implementation tests
```

## Test Organization

### Naming Convention
- **Files**: `[feature]_test.dart` (descriptive, not numbered)
- **Test groups**: `group('Feature Name', () { ... })`
- **Test cases**: `testWidgets('should do X when Y condition', (tester) async { ... })`

### Test Structure
Each test follows the **Arrange-Act-Assert** pattern:

```dart
testWidgets('should sort data when PagingSource has sort modifier', (tester) async {
  // Arrange - Set up test data and components
  final source = PagingSource<int, String>(...);
  final pager = Pager(source: source, builder: ...);

  // Act - Perform the action being tested
  await tester.pumpWidget(pager);
  await tester.pumpAndSettle();

  // Assert - Verify expected outcomes
  expect(find.text('expected'), findsOneWidget);
});
```

## Running Tests

### All Tests
```bash
dart test
```

### Specific Test Categories
```bash
# Paging3 API tests only
dart test test/paging3/

# Legacy API tests only  
dart test test/legacy/

# Dual API tests only
dart test test/dual_api_test.dart
```

### Individual Test Files
```bash
dart test test/paging3/pager_test.dart
dart test test/legacy/pager_sorting_test.dart
```

## API Versions

### Paging3 (Current - Recommended)
- Modern reactive stream-based architecture
- Better error handling and load states
- Memory efficient with proper cleanup
- Located in `test/paging3/`

### Legacy (Deprecated)
- Original widget-based API
- Maintained for backward compatibility
- Users should migrate to Paging3
- Located in `test/legacy/`

### Dual API
- Tests access to both APIs simultaneously
- Ensures no naming conflicts
- Validates migration scenarios
- Located in `test/dual_api_test.dart`

## Contributing

When adding new tests:
1. Use descriptive file and test names
2. Follow the directory structure by API version
3. Include comprehensive test coverage (happy path, edge cases, errors)
4. Use proper Arrange-Act-Assert structure
5. Add meaningful assertions with clear failure messages