# GentleAlarm

An iOS alarm clock app that replicates the native Clock UI while adding a configurable volume ramp-up — the alarm starts near-silent and gradually rises to full volume over a duration you choose.

## Features

- Create, edit, and delete alarms
- Repeat on selected days of the week (or one-time)
- Volume ramp-up: 30 seconds, 1, 2, 5, or 10 minutes
- Bundled alarm sounds (more can be added as `.caf` files)
- Snooze and dismiss from a full-screen overlay when the alarm fires
- Reliable background firing via a silent `AVAudioEngine` heartbeat

## Requirements

- iOS 17.0+
- Xcode 16+

## Building

Open `GentleAlarm.xcodeproj` in Xcode and run on a simulator or device.

```bash
xcodebuild -scheme GentleAlarm -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Testing

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

> Background alarm firing and battery impact require testing on a real device.

## Adding Alarm Sounds

Convert an audio file to the required format and drop it into `GentleAlarm/Resources/Sounds/`:

```bash
afconvert input.wav output.caf -d LEI16 -f caff
```

Then add a case to `AlarmSound.swift`.
