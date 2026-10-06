# Gun Mayhem 3 Online

Unofficial Windows Flash fan update based on the supplied Gun Mayhem 2 game.
The original ActionScript 2 engine, artwork, maps, physics and animation run in
the real AIR Flash runtime. There is no emulator and no conversion to another
game engine. Original game by Kevin Gu and its credited team.

## Play

Extract `dist/Gun Mayhem 3 Online.zip` and open **Gun Mayhem 3 Online.exe**.
Keep the entire extracted folder together. The Adobe AIR runtime and Photon
networking companion are bundled; no Steam, Flash plug-in, AIR or .NET install
is needed. Requires 64-bit Windows. This is a portable EXE folder, not a single
self-contained executable file.

Resize or maximize the window, or press **F11** for fullscreen. The original
900 × 600 stage scales uniformly, with dark borders where the screen shape
differs. Both sides of the game remain visible. **M** toggles overall sound.

Startup plays the original Armor Games intro, with its original sound and
animation together, with a black background through the Kevin Gu credit.
The GM1 main menu track begins after the intro and the
complete menu wipe and its sounds. Options, game setup, player setup and online
screens play GM1's original options/setup track. Entering a new menu stops all
previous sounds; the next track waits for the transition to finish. The original
Options menu's Music setting still works. Intro playback is skipped, including
its audio, when loading matches or returning to the menu.

Campaign, custom game, character customization, weapon library, challenges,
local multiplayer and all 21 original arenas remain available. The redesigned
main menu uses straight vector buttons, bold Flash typography and orange/blue
accents over the original live background fight. It is titled Gun Mayhem 3 Online.
Host and Join sit below Weapon Library, separated from Options and Credits.
The old More Games/Gun Mayhem 1 buttons, version 1.1 badge and desktop Online/Window
menu bar are removed. F11 and M remain available as keyboard shortcuts.
The Facebook and Armor Games menu icons are removed and their links disabled. The original creator
credits are retained, with IntelGenV2 credited for the Gun Mayhem 3 Online project.

## Online with friends

1. Click **Host** or **Join** on the main menu.
2. Enter your name and choose a region near your group. Everyone must select
   the same region.
3. The host clicks **Create room**, then **Copy invite**.
4. Friends enter the six-character room code and click **Join room**.
5. Work through **Rules → Map → Players**, following the original multiplayer
   setup. The host chooses the mode, crates, pickups, lives, preset and arena.
6. On Players, customize your color, hat, shirt, face, starting pistol, perk and
   team. Empty slots can be bots or reserved for friends. Guests click **Ready**,
   then the host clicks **Start match**.

Up to four people can play. Empty slots can use the original CPU opponents.
The room stays together for rematches. Settings changes clear guest readiness;
changing your fighter clears your own readiness. Players can join between rounds.
Press **Esc** or click **Room** during a match to resume, leave, or (as host)
end the round. Host, Join and room screens render inside
the Flash stage with the same fonts, gray panels and colored buttons as the
original menus. Connecting and room panels stay fixed while the game camera moves.
Cancelling or leaving returns to the main menu without replaying the intro, and
stops battle audio before menu music resumes. If the host leaves, the room closes;
host migration is not implemented.

Online controls: arrows or WASD to move/jump, Z/J to shoot, X/K for dynamite.
Offline controls remain configurable in the original Options menu.

## The two approved extras

- **Sniper Showdown:** everyone starts with the original Classic Sniper;
  weapon crates are disabled.
- **Supply Storm:** original weapon crates arrive about every two seconds
  instead of every ten seconds. Original movement and weapons are unchanged.

Select **Original rules** to play without either preset. These presets can be
selected in the online lobby. No extra maps, guns or characters have been added.

## Photon and direct peers

The bundled Photon Realtime 5.1.20 SDK uses App ID
`e1d6cd78-cff9-4721-85c6-24fd8a32b968` for private cloud rooms. No server address,
port forwarding, LAN setup or Steam account is required.

The host simulates the original Flash game. Guests receive compressed original
vector display-object snapshots. A small native network companion establishes
UDP peer links using candidates exchanged through Photon and the free
`stun.cloudflare.com:3478` STUN service. It uses authenticated, fragmented full
snapshots so packet loss cannot permanently corrupt the scene. If direct
delivery stalls, Photon relays snapshots automatically. Lobby operations and
reliable player input remain on Photon. This is a hybrid P2P architecture;
Realtime 5 does not itself supply a direct-peer transport.

Photon has been tested using this App ID with four concurrent clients, direct
snapshots, forced relay fallback, readiness, rematches and disconnects. Direct
tests ran on this PC; this does not prove connectivity or latency between two
separate households. NAT restrictions are handled by the relay fallback.
There is no rollback or client-side prediction, so internet latency affects
guest controls. Only share room codes with people you want to play with.

No paid plan was purchased or enabled. As checked on 2026-10-04, Photon Realtime's
free plan is **development only**, capped at **20 concurrent users per App ID**,
with **60 GB monthly traffic**. It is not an unlimited free public-release plan.
Your Photon dashboard controls the actual subscription and allowance.
See https://www.photonengine.com/realtime/pricing .
Cloudflare STUN is free; no paid TURN relay is used:
https://developers.cloudflare.com/realtime/turn/faq/ .
The AIR free-tier license may show its startup splash.

## Source and build

- `as2/`: original-engine input bridge, menu UI/audio, approved presets and guest renderer.
- `src/`: ActionScript 3 desktop window and Photon session controller.
- `photon/`: C# networking companion only. Gameplay stays in ActionScript.
- `ref/gunmayhem2_decomp.swf`: original build input.
- `assets/gm1-menu.mp3`, `assets/gm1-setup.mp3`: original GM1 tracks; see `assets/CREDITS.md`.
- `tools/PatchGame.java`: adds bridge scripts while preserving original bytecode.
- `server/`, `src/LanServer.as`, `src/Connection.as`, `tests/server.test.mjs`:
  previous LAN implementation retained for reference; not shipped or used.

Build dependencies: JDK 21, .NET SDK 9, Windows ActionScript AIR SDK 51.1,
and JPEXS FFDec. The provided Photon ZIP has been extracted in `vendor/photon`.
Point the build at your installed AIR SDK and FFDec:

```powershell
.\build.ps1 -AirSdk 'C:\SDKs\AIR' -Ffdec 'C:\SDKs\ffdec\ffdec.jar' -Package
python tools/verify_assets.py
python tests/photon_smoke.py
python tests/photon_smoke.py --relay-only
python tools/startup_smoke.py --air-sdk 'C:\SDKs\AIR'
python tools/menu_smoke.py --air-sdk 'C:\SDKs\AIR' --name menutest
python tools/room_smoke.py --air-sdk 'C:\SDKs\AIR' --name roomtest --scenario pages
python tools/room_smoke.py --air-sdk 'C:\SDKs\AIR' --name leavetest --scenario leave
python tools/room_smoke.py --air-sdk 'C:\SDKs\AIR' --name canceltest --scenario cancel
python tools/smoke.py --air-sdk 'C:\SDKs\AIR' --name mytest --players 4 --variant 2
```

Photon tests create temporary private cloud rooms and require internet access.
`verify_assets.py` verifies all 563 original sprite timelines and 786 original
ActionScript blocks, along with every original art/placement tag. The old main
menu display is hidden and replaced with vector UI; preview aliases reuse the
original map and character artwork. Additional
scripts handle networking, display scaling, menu UI and music. All original game
rights remain with their owners. This is not an official sequel. The generated
development certificate is not a Windows publisher signature.
