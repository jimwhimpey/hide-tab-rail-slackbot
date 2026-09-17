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

- **Reboots / logins**: the launchd agent has `RunAtLoad` and `KeepAlive`, so
  the supervisor is always running while you're logged in.
- **Slack updates**: nothing inside `Slack.app` is modified.
  `--remote-debugging-port` is a Chromium flag every Electron app accepts, so
  updates don't undo anything. Only the CSS selector itself can go stale if
  Slack renames a class; edit `custom.css` if that happens.
- **Quitting and relaunching Slack**: quitting Slack leaves it quit. If you
  relaunch it from the Dock or Spotlight (without the flag), the supervisor
  notices within a couple of seconds, restarts it with the flag, and re-injects.
- **Page reloads (Cmd-R, reconnects)**: the injector stays attached and
  re-injects on every `Page.loadEventFired`.
- **Crashes**: if the injector or supervisor dies, launchd restarts it.

## Caveat

While Slack runs with the debug port open, any local process can drive your
Slack session through `localhost:9222`. Don't use this on a shared machine.

Logs: `/tmp/hide-tab-rail-slackbot.log`
