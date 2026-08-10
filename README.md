# GentleAlarm

My first experiment with vibe-coding! I was frustrated with the lack of a volume ramp-up option for alarms in the native iOS Clock app,
so had a crack at building one myself. As it turns out, because of limitations on what a third-party app can do in terms of scheduling
wake-up, this is a difficult thing to achieve in iOS. As such, I would say this app is not reliable enough to use as your everyday
alarm clock, but a fun experiment in any case.

This repository also includes an automated review feature. When a pull request is submitted, a Github Action fires which runs an automated
review of the PR, flags (and blocks merging on) any issues, and suggests changes. The AI review can be overridden with an approving review
from a code owner.

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
