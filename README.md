# World Cup 2026 Menubar

A simple macOS menu bar app for following the [2026 FIFA World Cup](https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026).

The app shows the current live match, or the next upcoming match, directly in the macOS menu bar. Opening the menu bar item shows matches from the last 24 hours and the next 24 hours, with a fallback to upcoming matches when nothing is nearby.

Scores and match metadata are loaded from ESPN's public soccer scoreboard API.

## Features

- Menu bar score display for live matches
- Upcoming match display in the menu bar when no match is live
- Popover list of recent and upcoming matches
- Venue, kickoff time, live clock, and full-time status in match rows
- Optional Dynamic Notch live-score presentation
- Configurable notifications for kickoff, full time, and goals
- Dockless menu bar app behavior

## Requirements

- macOS Tahoe
- Network access to ESPN's public scoreboard API

## Run Locally

1. Open `WorldCup2026Menubar.xcodeproj` in Xcode.
2. Select the `WorldCup2026Menubar` scheme.
3. Build and run.

The app launches as a menu bar item and does not appear in the Dock. Look for the current score or upcoming match text in the macOS menu bar.

## Settings

Open the menu bar item, then click the gear icon to configure:

- Whether live scores appear in the menu bar or Dynamic Notch
- Kickoff notifications
- Full-time notifications
- Goal notifications

macOS may ask for notification permission the first time notifications are enabled.

