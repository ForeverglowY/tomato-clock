#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
check_dir=$(mktemp -d /tmp/tomato-behavior.XXXXXX)
cd "$project_dir"
swiftc -parse-as-library \
  Sources/TomatoClock/TimerEngine.swift \
  Sources/TomatoClock/DurationReminderPresenter.swift \
  Sources/TomatoClock/TomatoStore.swift \
  Tests/TimerBehaviorChecks.swift \
  -o "$check_dir/check-timer"
"$check_dir/check-timer"
