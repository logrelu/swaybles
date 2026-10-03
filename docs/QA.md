# Release QA

Unit tests (`cd mac && swift test`) cover the logic: focus, dozing, settings, charm text, hit-testing.
They can't see the screen. This list covers what they can't: the overlay, the menu bar, the
packaged app. Run it on the **packaged** app (`mac/scripts/make-app.sh`, then open the zip's app),
not `swift run`. About 10 minutes. Note the version and date at the bottom.

If a step fails, fix it or write it down in the release notes. Don't ship around it silently.

## 0. Clean start
- [ ] Quit any running Swaybles. Reset to a first-run state: `defaults delete com.swaybles.app` (or the bundle id in `make-app.sh`).
- [ ] Open the zip's app via right-click → Open. It launches; no crash, no permission prompt of any kind.
- [ ] No Dock icon. A sparkles icon appears in the menu bar.
- [ ] First launch hangs **just Boo**, and Boo gives a little hello swing.

## 1. Overlay
- [ ] Clicks pass through everywhere except on a charm (click a window, a link and the menu bar under the overlay).
- [ ] Hovering a charm shows an open hand; hovering a pin shows a left-right cursor; elsewhere, the normal arrow.
- [ ] Swiping the cursor through a charm makes it swing. Dragging it moves it; letting go swings it. The rope never stretches visibly past its length.
- [ ] Dragging a pin slides the charm along the top and stays after relaunch. It stops short of the screen edges.
- [ ] The charm stays on top of a full-screen app and on every Space.
- [ ] Charms hang under the menu bar, not behind it. With an external monitor attached, they're on the one with the menu bar.
- [ ] Plug in / unplug a monitor, or change resolution, while running: charms reposition, no crash.
- [ ] Left alone, swinging settles and CPU drops to about 0% (Activity Monitor, "Swaybles", 30 s after the last swing).
      With Breeze or the Rainbow cord on, it keeps animating; that's expected.

## 2. Focus Crew
- [ ] Hang Timer Ghost, Chalkboard Cat, Banner Bat, Task Lantern, Cocoa Buddy from the Studio. The 9th charm is refused (max 8).
- [ ] Tapping Timer Ghost starts a focus session. Dragging it does not.
- [ ] Menu bar shows the minutes left; Timer Ghost's ring fills. 15 / 25 / 45 presets work.
- [ ] Stop mid-session: no cheer, no win counted, no message. Nothing about "giving up".
- [ ] Let a 15-minute session finish (or start one, change the system clock forward, and tick): every charm wiggles, hearts burst, Chalkboard Cat cheers, Cocoa Buddy swings in for the break, and a "Glass" sound plays if Sound is on. The timer does **not** restart.
- [ ] Task Lantern shows the goal; with none set it says "pick one thing".
- [ ] Banner Bat shows "Day N / 90" (or the year countdown if chosen). Starting the 90 days celebrates.
- [ ] With no Chalkboard Cat or Banner Bat hanging, their text still shows under the first charm.

## 3. Dozing
- [ ] Set the idle time to the minimum in the Studio. Leave the Mac alone: charms droop and settle, no message.
- [ ] Move the mouse: they stretch, and a "welcome back" line appears. No guilt wording.
- [ ] Never dozes during a focus session.

## 4. Accessibility and calm
- [ ] System Settings → Accessibility → Display → Reduce motion ON: swings are gentler, sparkles don't fly (they pop in place), tap-to-nudge is weaker.
- [ ] Studio's "Calmer" and "Still" options do what they say. "Still" means no swinging at all.
- [ ] Studio and menu are fully usable with the keyboard and VoiceOver reads the controls.
- [ ] Light and dark appearance both look right.

## 5. Studio and settings
- [ ] ⌘, opens the Studio. It never opens by itself at launch.
- [ ] Rope styles (all 8), size, sound and hide/show each take effect immediately.
- [ ] Hide → charms vanish; Show → they return with a hello.
- [ ] My photos: add a picture, it hangs as a polaroid; remove it, and it's gone from the Studio and the screen. A non-image file is refused without a crash.
- [ ] Quit and relaunch: every setting, charm position, goal and win count is kept.
- [ ] Upgrading: install over the previous release's data; settings survive (a new field must not reset them).

## 6. Privacy and the package
- [ ] First run triggers **no** macOS permission prompt (Accessibility, Input Monitoring, Screen Recording, Notifications, network).
- [ ] Little Snitch / `nettop -p $(pgrep Swaybles)` shows no network connection over a few minutes.
- [ ] `codesign -dv Swaybles.app` is valid (ad-hoc is expected); the app is universal (`lipo -archs`: `x86_64 arm64`).
- [ ] The version in the app and in the zip name match `package.json`.
- [ ] All copy reads as kind. Nothing shames, nothing is red, nothing says missed, failed or behind.
- [ ] Quit from the menu: the overlay goes away and the process exits.

## Sign-off
| Version | Date | Tested on (macOS, chip) | Result / notes |
|---|---|---|---|
|  |  |  |  |
