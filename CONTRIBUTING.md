# Contributing to GentleAlarm

Thanks for your interest in contributing! Here's how to get involved.

## Getting Started

1. Fork the repository and clone your fork.
2. Open `GentleAlarm.xcodeproj` in Xcode 16+.
3. Create a new branch for your change: `git checkout -b my-feature`.

## What to Work On

- Check the [Issues](../../issues) tab for open bugs or feature requests.
- For significant changes, open an issue to discuss the approach before writing code — this avoids wasted effort if the direction isn't a fit.

## Making Changes

- Keep pull requests focused. One feature or bug fix per PR makes review much easier.
- Follow the existing code style and adhere to Swift conventions.
- Third-party dependencies will be considered, provided a sufficiently good reason for importing them.
- Add or update tests for any logic you change. All tests must pass before submitting.
- Test background alarm firing on a real device if your change touches `AlarmManager`, `AudioEngine`, or scheduling logic — the simulator does not fully replicate background execution.

## Running Tests

```bash
# Unit tests
xcodebuild test -scheme GentleAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GentleAlarmTests

# UI tests
xcodebuild test -scheme GentleAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GentleAlarmUITests
```

## Submitting a Pull Request

1. Ensure all tests pass.
2. Write a clear PR description explaining *what* changed and *why*.
3. Reference any related issue (e.g. `Closes #42`).
4. Be responsive to review feedback — PRs with no activity for 30 days may be closed.

## Reporting Bugs

Open an issue with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Device/iOS version

## Code of Conduct

Be respectful and constructive. Contributions of all experience levels are welcome.
