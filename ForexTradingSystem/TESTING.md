# Testing Framework Documentation

## Running Tests
```bash
# Install test dependencies
pip install -r requirements-test.txt

# Run all tests with coverage
pytest

# Run specific test file
pytest tests/test_data_feed.py

# Generate HTML coverage report
pytest --cov=modules --cov-report=html
```

## Test Structure
- `tests/`: Contains all test files
- `test_*.py`: Test files follow this naming convention
- `pytest.ini`: Configuration for test runner

## Writing Tests
1. Use descriptive test names
2. Keep tests isolated and independent
3. Use fixtures for common setup/teardown
4. Follow AAA pattern (Arrange, Act, Assert)

## CI/CD Integration
- Tests run automatically on push/pull request
- Coverage reports uploaded to Codecov
- Pipeline defined in `.github/workflows/ci.yml`

## Best Practices
- Aim for 80%+ coverage
- Test edge cases and error conditions
- Use property-based testing where applicable
- Keep tests fast and reliable
