# Typewriter Panel - Unit Tests

## Publication System Tests

This test suite covers the publication/staging system of the Typewriter panel.

### Test Coverage

#### 1. **Staging Model Tests** (`test/models/staging_test.dart`)
Tests for the `StagingState` enum and `PublishPagesIntent`:
- ✅ Verifies all three staging states exist (Publishing, Staging, Production)
- ✅ Validates correct labels, colors, and names for each state
- ✅ Ensures proper ordering and indices
- ✅ Tests PublishPagesIntent creation

#### 2. **Communicator Publish Tests** (`test/models/communicator_publish_test.dart`)
Tests for the publish functionality in the Communicator:
- ✅ **Publish Method Tests:**
  - Emits publish event when in staging state and connected
  - Does NOT publish when socket is null
  - Does NOT publish when socket is not connected
  - Does NOT publish when in production state
  - Does NOT publish when in publishing state
  - Sends empty string as data payload

- ✅ **Staging State Handler Tests:**
  - Updates state to publishing when receiving "publishing"
  - Updates state to staging when receiving "staging"
  - Updates state to production when receiving "production"
  - Defaults to production for unknown states
  - Handles empty strings correctly

- ✅ **Integration Workflow Tests:**
  - Full state transition cycle (production → staging → production)
  - Publish only allowed in staging state
  - Prevents publish during publishing state

#### 3. **Staging Indicator Widget Tests** (`test/widgets/staging_indicator_test.dart`)
Tests for the UI component:
- ✅ **Display Tests:**
  - Shows correct label for each state
  - Applies correct colors (Green/Orange/LightBlue)
  - Shows dotted border only in staging state
  - Bold font weight for labels

- ✅ **Publish Button Tests:**
  - Visible only in staging state
  - Hidden in production and publishing states
  - Calls `publish()` when tapped
  - Hover animation support

- ✅ **State Transition Tests:**
  - UI updates correctly when state changes
  - Publish button appears/disappears appropriately

### Running the Tests

#### Prerequisites
1. Install dependencies:
   ```bash
   cd app
   flutter pub get
   ```

2. Generate mock files:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

#### Run All Tests
```bash
flutter test
```

#### Run Specific Test Files
```bash
# Staging model tests
flutter test test/models/staging_test.dart

# Communicator publish tests
flutter test test/models/communicator_publish_test.dart

# Widget tests
flutter test test/widgets/staging_indicator_test.dart
```

#### Run Tests with Coverage
```bash
flutter test --coverage
```

To generate an HTML coverage report:
```bash
genhtml coverage/lcov.info -o coverage/html
```

### Test Architecture

#### Mocking Strategy
- Uses **Mockito** for mocking Socket and Communicator
- Mock files are generated in `*.mocks.dart` files
- Annotations: `@GenerateMocks([Socket, Communicator])`

#### Provider Overrides
Tests use Riverpod's `ProviderContainer` with overrides to:
- Inject mock sockets
- Control staging state
- Test in isolation

#### Widget Testing
- Uses `pumpWidget` for rendering
- `pumpAndSettle` for animations
- Verifies text, colors, and interactions

### Adding New Tests

1. Create test file in appropriate directory:
   - `test/models/` for model/business logic tests
   - `test/widgets/` for widget tests

2. Add mock annotations if needed:
   ```dart
   @GenerateMocks([YourClass])
   ```

3. Run code generation:
   ```bash
   flutter pub run build_runner build
   ```

4. Write tests following the existing patterns

### CI/CD Integration

Add to your CI pipeline:
```yaml
- name: Run tests
  run: |
    cd app
    flutter pub get
    flutter pub run build_runner build
    flutter test --coverage
```

### Known Limitations

1. **Socket.IO Testing**: Real socket connections are not tested; only mocked behavior
2. **Rive Animations**: The status icon animation is not fully testable in unit tests
3. **Hover Effects**: Hover interactions are limited in widget tests

### Test Metrics

- **Total Test Cases**: 30+
- **Code Coverage Target**: >80% for publication system
- **Test Execution Time**: ~5-10 seconds

### Troubleshooting

#### Mock Generation Fails
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Tests Fail After Dependency Updates
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

#### Import Errors
Ensure mock files are generated and imported correctly:
```dart
import 'your_test_file.mocks.dart';
```

---

## Future Test Additions

Recommended areas for expansion:
- [ ] Integration tests for full publish workflow
- [ ] Performance tests for large data sets
- [ ] Error handling and edge cases
- [ ] Network failure scenarios
- [ ] Concurrent user scenarios
