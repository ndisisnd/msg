---
name: emulate runners
description: The three launch recipes /emulate can run — Expo, native iOS, native Android — each with its ready signal, its cold-boot rule, and what it prints back
type: reference
---

# Launch recipes

One section per runner + platform pair. `refs/protocol.md` Step 5 picks the
section; this file is the only place the actual commands live.

**Precedence.** A repo that declared `emulate_cmd` in `devkit/PLATFORMS.md`
overrides everything here. These recipes are the fallback for a repo that
declared nothing — which is most repos, and is why they have to be good.

**Three rules apply to every recipe below.**

1. **Background the long-lived thing.** A dev server or an emulator must outlive
   this run. `run_in_background: true`, with stdout redirected to the log path
   the banner will print. Never a foreground command that holds the turn.
2. **Wait on a signal, never on a clock.** Each recipe names a ready signal — a
   log line or a command that exits 0. Poll that. A foreground `sleep` is never
   the answer.
3. **Raise the window.** Booting a simulator headlessly and calling it launched
   is the single most likely way this skill disappoints someone.

## Log paths

```
.emulate/<platform>-<epoch>.log
```

Created under the repo, gitignored by the same rule that covers other run
artifacts. If `.emulate/` is not ignored, write to `$TMPDIR/emulate-<epoch>.log`
instead and say so in the banner — `/emulate` does not modify `.gitignore`,
because it writes nothing to the repo.

---

## Expo — iOS

```bash
mkdir -p .emulate
npx expo start --ios > .emulate/ios-$(date +%s).log 2>&1
```

Metro boots the simulator itself, which is why there is no separate `simctl`
step. Pass the device through when one was chosen:

```bash
npx expo start --ios --device "$EMULATE_DEVICE_NAME"
```

**Ready signal.** A line matching `Metro waiting on` or `Bundling complete` in
the log. On a cold cache the first bundle can take minutes — that is normal, and
the banner should say the log is where to watch it.

**Cold boot.** Not needed. Expo installs onto whatever simulator is running.

**Raise.** `open -a Simulator` after the ready signal, in case Metro attached to
an already-running-but-backgrounded simulator.

## Expo — Android

```bash
mkdir -p .emulate
npx expo start --android > .emulate/android-$(date +%s).log 2>&1
```

Expo will start an AVD if none is running, but it picks its own. When a device
was chosen, boot it first so Expo attaches to the right one:

```bash
emulator -avd "$EMULATE_DEVICE_NAME" > .emulate/avd-$(date +%s).log 2>&1 &
adb wait-for-device
```

**Ready signal.** `adb wait-for-device` exits 0, then `Metro waiting on` in the
Expo log.

**Cold boot.** Not needed.

---

## Native iOS

```bash
mkdir -p .emulate
xcrun simctl boot "$EMULATE_DEVICE_ID" 2>/dev/null || true   # already booted ⇒ fine
open -a Simulator
xcodebuild -workspace <App>.xcworkspace -scheme <Scheme> \
           -destination "id=$EMULATE_DEVICE_ID" \
           -derivedDataPath .emulate/DerivedData build \
  > .emulate/ios-$(date +%s).log 2>&1
xcrun simctl install "$EMULATE_DEVICE_ID" <path to .app>
xcrun simctl launch "$EMULATE_DEVICE_ID" <bundle id>
```

`simctl boot` on an already-booted device exits non-zero and that is not an
error — it is the common case. Swallow it rather than treating it as failure.

**Discovering the workspace and scheme.** `xcodebuild -list -json` in `ios/`
names both. If it reports more than one scheme and none matches the workspace
name, that is a **loud stop**, not a guess: print the schemes and ask for
`--device`-style precision via `emulate_cmd` in `devkit/PLATFORMS.md`.

**Ready signal.** `simctl launch` prints the pid on success.

**Cold boot.** Required only when a previous install left the app in a broken
state and the user asked for a clean run. Pass `--cold-boot --device-id` to the
sweep in that case; otherwise never.

## Native Android

```bash
mkdir -p .emulate
emulator -avd "$EMULATE_DEVICE_NAME" > .emulate/avd-$(date +%s).log 2>&1 &
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done'
./android/gradlew -p android installDebug > .emulate/android-$(date +%s).log 2>&1
adb shell am start -n <package>/<activity>
```

`adb wait-for-device` returns as soon as the device is *visible*, which is well
before it is *usable* — the `sys.boot_completed` poll is what stops an install
racing a half-booted system image. That poll runs inside `adb shell`, on the
device, so it is not a foreground sleep in this session.

**Discovering the package and activity.** `android/app/src/main/AndroidManifest.xml`
names both. When the launcher activity cannot be resolved, use
`adb shell monkey -p <package> -c android.intent.category.LAUNCHER 1` — it
starts whatever the launcher would start.

**Ready signal.** `am start` prints `Status: ok`.

**Cold boot.** Only on explicit request, same rule as iOS.

---

## When the recipe cannot be resolved

Every branch above ends in either a launch or a **loud stop** — never a guess. A
missing scheme, an unresolvable launcher activity, or two candidate workspaces
are all cases where `/emulate` stops and tells the user to declare
`emulate_cmd` in `devkit/PLATFORMS.md`, quoting the exact column. That column
exists precisely so an unusual repo has a way to answer this once instead of
fighting detection on every run.
