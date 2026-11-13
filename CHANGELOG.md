# EzFishing

## v1.0.1

- The pole swap now always remembers your last weapons, so swapping back also works when you put the pole on by hand from your bags. Your weapons are no longer forgotten after swapping back.

## v1.0.0

EzFishing 1.0: tested and working on WoW Forever.

- Fixed the pole swap: Forever blocked it ("EzFishing has been blocked from an action only available to the Blizzard UI"). The pole button on the HUD, the "Swap pole / weapons" key and the Cast key's pole equip all work again, and your existing key binding is kept.
- Swapping back puts both weapons on in one press, each in the right hand even if you carry two of the same weapon.
- New: `/click EzFishingPoleButton` swaps pole and weapons from a macro.
- Forever doesn't let addons change your gear on their own, so EzFishing no longer swaps your weapons back by itself when combat starts or when you stop fishing. Those two options now remind you which key swaps back instead.
- `/ezf pole` now tells you how to swap (addons can't swap gear from a slash command).

## v0.1.2

- Fixed "EzFishing has been blocked from an action only available to the Blizzard UI" when searching the game options (e.g. "scr"). The key binding rows on the EzFishing options page tainted the search; they are replaced by a button that opens the Key Bindings page.

## v0.1.1

- Fixed the HUD's skill line running into the zone requirement when a pole or lure bonus is shown. The HUD is a little wider and its texts can no longer overlap.

## v0.1.0

- One key to cast and hook: bind "Cast / Hook", press to cast, press again when the bobber splashes.
- Double right-click in the world to cast (and to hook while fishing).
- Fishing sound preset: music and ambience off, effects at max while fishing, restored afterwards.
- Auto-loot while fishing, bobber soft-target icon.
- Lure button and timer, optional auto-lure on the Cast key, expiry warning.
- Pole swap: equip the best pole in your bags and swap back to your weapons (button, key, combat or idle).
- Catch log: per session, per zone and all-time catches, catches per hour, typical bite time, skill-ups.
- Zone hint: shows the skill needed for no getaways in your zone.
- Compact HUD bar and an options page under Esc > Options > AddOns.
