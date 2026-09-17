# hide-tab-rail-slackbot

Hides the Slackbot button in the Slack desktop app's tab rail (and lets you
inject any other CSS) without patching the Slack app bundle.

```css
.p-tab_rail__button--slackbot { display: none !important; }
```

macOS only. Requires Node 22 or newer (`node -v`).

## Install

```zsh
git clone https://github.com/jimwhimpey/hide-tab-rail-slackbot.git
cd hide-tab-rail-slackbot
./install.sh
```

That's it. Slack restarts once with the debug port enabled and the CSS is
applied. It stays applied across reboots, Slack updates, and reloads.

If Slack is in **System Settings → General → Login Items**, remove it there;
the agent launches Slack for you.

## Uninstall

```zsh
./uninstall.sh
```

## Customising the CSS

Edit `custom.css`, then restart the agent so it re-reads the file:

```zsh
launchctl kickstart -k gui/$UID/hide-tab-rail-slackbot
```

## How it works

| File | Role |
| --- | --- |
| `slack-css.sh` | Supervisor. Launches Slack with `--remote-debugging-port=9222` and runs the injector whenever Slack is up. |
| `inject.mjs` | Connects to Slack over the Chrome DevTools Protocol, adds a `<style>` tag with `custom.css`, and re-adds it after page reloads. |
| `hide-tab-rail-slackbot.plist` | launchd agent template so the supervisor runs at login and is restarted if it dies. |
| `install.sh` / `uninstall.sh` | Fill in the template paths and register / remove the agent. |

## Why it's durable

Each layer covers a different way the CSS could stop being applied.

**Reboots and logins.** The launchd agent is installed in
`~/Library/LaunchAgents` with `RunAtLoad` and `KeepAlive`, so the supervisor
script (`slack-css.sh`) is running any time you're logged in, and launchd
restarts it if it ever exits.

**Slack updates.** Nothing inside `Slack.app` is modified, so there's no
patched bundle for an update to overwrite and no code-signing or ASAR
integrity check to fight. `--remote-debugging-port` is a Chromium flag that
every Electron app honours, so it keeps working across Slack and Electron
versions. The only thing that can go stale is the CSS selector itself, if
Slack renames a class; that's a one-line edit to `custom.css`.

**Quitting and relaunching Slack.** The supervisor loops rather than exiting.
Quit Slack and it stays quit. Open Slack from the Dock or Spotlight (which
won't pass the flag) and within about two seconds the supervisor sees the
debug port isn't open, quits that instance, relaunches it with the flag, and
re-injects. You'll see one brief flicker, then it's applied.

**Page reloads.** The injector (`inject.mjs`) holds its DevTools socket open
and re-applies the style on every `Page.loadEventFired`. That covers Cmd-R and
Slack's own reconnect reloads. It's event-driven, not polling, so it does no
work while Slack is idle.

**Crashes.** If the injector dies, the supervisor loop reruns it. If the
supervisor dies, launchd brings it back.

**Machine or path changes.** The plist is a template; `install.sh` fills in
the clone location and the directory of your `node` binary, so moving the
folder or switching Node installs is just `./install.sh` again.

## Performance overhead

Very little, and none of it is continuous.

- **Injector process** (`node inject.mjs`): roughly 30–50 MB of RAM idle with
  one open WebSocket. It does nothing between page loads, so CPU is
  effectively zero. Slack itself typically uses 500 MB+.
- **Supervisor loop** (`slack-css.sh`): while Slack is running it is blocked
  waiting on the injector and costs nothing. Only while Slack is *closed* does
  it wake every two seconds to run `pgrep` and `nc`, a few milliseconds of CPU.
- **Inside Slack**: `Page.enable` makes Chromium send a handful of tiny
  lifecycle messages per navigation, not a stream. A one-rule `<style>` tag
  has no measurable render cost.
- **Debug port**: Chromium keeps a listener open on `localhost:9222`. Idle it
  costs nothing; its significance is security, not performance (see below).

Battery and CPU impact should be indistinguishable from not running it.

## Caveat

While Slack runs with the debug port open, any local process can drive your
Slack session through `localhost:9222`. Don't use this on a shared machine.

Logs: `/tmp/hide-tab-rail-slackbot.log`
