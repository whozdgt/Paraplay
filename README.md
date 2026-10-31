<img src="packaging/icon-512.png" width="96" alt="Paraplay icon">

# Music: a lightweight FLAC / Hi-Res player (Qt Quick + libmpv)

Native C++ and QML. No browser engine, no Python. Playback goes through libmpv, so FLAC, ALAC, WAV, MP3, AAC, OGG and OPUS (including 24-bit and 96/192 kHz files) are decoded by a mature engine, gaplessly.

Square corners, frosted white glass, black text with a green accent, JetBrains Mono. Everything is free: there is nothing to unlock.

## Install dependencies (CachyOS / Arch)

    sudo pacman -S --needed base-devel cmake qt6-base qt6-declarative qt6-wayland mpv taglib ttf-jetbrains-mono

Needs Qt 6.6 or newer and TagLib 1.13 or newer, both fine on current Arch.

## Build and install

    git clone https://github.com/whozdgt/Paraplay.git && cd Paraplay
    ./update.sh --here

That builds the player and installs it for your user (into `~/.local`, no `sudo`), with a launcher entry. Start it from your app launcher, or run `musicplayer --music ~/Music`.

To just try it without installing:

    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build -j
    ./build/musicplayer --music ~/Music

The music folder is remembered after the first run. Change it in Settings → Directories (press Enter to scan). The library is cached on disk, so later starts only re-check changed files.

## Updates

Settings → Updates. The player asks GitHub for the newest release (at most twice a day, switch it off there) and shows "Update available" at the bottom of the sidebar. **Update now** downloads that release's source, builds it on your computer at low priority (music keeps playing) and installs it; then **Restart**. Building on your own machine means it always matches your Qt, mpv and TagLib. In-app updating works once the player was installed with `./update.sh --here`.

Releases are made by pushing a tag such as `v0.6.1`; the version must match `project(musicplayer VERSION …)` in `CMakeLists.txt`. The release notes are the top section of `CHANGES.md`.

## Your own server (Navidrome, Subsonic, Jellyfin)

Sidebar → SOURCES → **Add a server…**, or Settings → Servers. Pick Navidrome / Subsonic or Jellyfin, enter the address, username and password.

- Songs play as the **original files**, never re-encoded, with the same quality badges.
- "All sources / This computer / your server" filters Songs, Albums and Artists. A small cloud marks streamed music.
- The song list is saved on this computer so the library opens instantly; it refreshes on start and every few hours, or press Sync now.
- Your password is not saved. Navidrome/Subsonic keeps a one-way sign-in token and Jellyfin an access token, in a private file only your user can read.
- Servers on your own network with a self-signed certificate: turn on "Allow a self-signed certificate". The first certificate you accept is remembered and a different one later is refused.
- Not built yet: WebDAV and plain web folders.

## What works

- Songs, Albums and Artists views; click a song to play, click an album or artist to filter. Cover Flow carousels.
- Format column (e.g. `FLAC 24/96`), green marker on Hi-Res tracks, quality readout in the player bar and expanded player.
- Local playlists. Search with suggestions.
- Square cover or spinning record, frosted glass, album-colour glow, theme colours, all in Settings (gear, top right).
- Lyrics: a `.lrc` file with the same name next to the song, lyrics saved in the song's tags, or (switchable) looked up on lrclib.net. Synced lyrics follow the music and you can tap a line to jump to it. On a phone, tap the cover or the lyrics button in the player.
- Media keys, `playerctl` and waybar media module (MPRIS).
- Optional profile (username and password, no email) with playlist sync, profile picture and banner.
- Home page: a greeting, then the sections you choose in Settings → Home page (switch them on or off, move them up or down). Signed in, it shows your friends and what they are playing, follow requests, and your top artists; as a guest it shows your playlists, albums and songs, with a small "Sign up / in" button beside "Guest".
- Friends: find people (the person-with-a-plus button on Home), follow them, see what they play, open public profiles and play their shared playlists from your own copies of the songs. Public or Private profiles, with a Preview of what strangers see. Needs `supabase/social.sql` run once (see below).
- Keys: Space play/pause, Left/Right seek 5 s, N / P next / previous, Esc close panel.

## Not built yet

Spotify and YouTube Music (greyed out, "soon"), shuffle/repeat, WebDAV / web-folder sources, the "Horizon" lyrics font (JetBrains Mono is used for now).

## What goes online

Nothing, unless you turn it on:

- **Profile:** if you make an account, your username, profile text, playlists and pictures are stored in the project's Supabase database. Your music files never leave your computer.
- **Friends:** who you follow, who you block, and reports you send are stored there too. A playlist is only visible to others if you mark it Shared and your profile allows it; they get song titles, artists, albums and lengths, never files or file paths. "Show what I'm listening to" is off by default; when you turn it on, the title, artist and quality of the song playing are sent while it plays, and removed when you switch it off.
- **Top artists:** the Home page counts what you play (a play is half the song, or 30 seconds) in a plain file on your device. It is never uploaded, and Settings → Home page can wipe it.
- **Lyrics:** for a song with no lyrics of its own, its artist, title, album and length are sent to lrclib.net (Settings → Customisation → Look up lyrics online switches it off). Found lyrics are kept on your device, so each song is only asked about once.
- **Artist pictures:** artist names are sent to Deezer to find a photo (Settings → Customisation switches it off).
- **Updates:** a request to GitHub's releases page.
- **Servers:** only the servers you add.

## Database setup (once, for the project owner)

The profile and friends features use a Supabase project. Run these in the Supabase dashboard → SQL Editor, in order, once each (all are safe to run twice): `supabase/images.sql` (profile pictures), then `supabase/social.sql` (friends, public profiles, and the privacy rules). `social.sql` also replaces the older row-level rules on profiles and playlists with "you can only touch your own rows"; everyone else reaches your data only through functions that hide whatever a Private profile keeps back.

## Hyprland

- Blur: the app draws a translucent window and Hyprland blurs behind it, as long as blur is enabled (`decoration { blur { enabled = true } }`, on by default).
- Square corners: Hyprland rounds windows itself. To keep the boxy look, add a rule for class `musicplayer` setting rounding to 0. Window-rule syntax changed between Hyprland releases, so check the wiki for your version (older form: `windowrulev2 = rounding 0, class:^(musicplayer)$`).

## Hi-Res / bit-perfect

The player asks for the file's own sample rate, but PipeWire decides what the sound card actually runs at, and by default it resamples everything to one fixed rate. To let it follow your files, create `~/.config/pipewire/pipewire.conf.d/10-hires.conf`:

    context.properties = {
        default.clock.allowed-rates = [ 44100 48000 88200 96000 176400 192000 ]
    }

then `systemctl --user restart pipewire pipewire-pulse wireplumber`.

- **Bit-perfect output** (Settings → Audio): when on, no ReplayGain or volume changes are applied.
- **Match track sample rate:** when off, output is forced to 48 kHz. It takes effect on the next start.

## Memory notes

Idle cost is the Qt Quick runtime, libmpv with small demuxer buffers (4 MiB local, 16 MiB for streams), and one track list shared by your folder and your servers (a few MB for tens of thousands of tracks). While you search, only the chosen cover stays loaded. Animations only run while a song plays and the record cover is selected. Check with `ps -o rss,cmd -C musicplayer`.

## Licence

The player's own code is under the [MIT licence](LICENSE).

It uses other projects under their own licences, which matter if you ever ship a build to someone else:

- **Qt 6** (LGPLv3 / GPLv3 / commercial). Linking it dynamically, as the Linux build does, is the simple case. Windows, Android and iOS need extra care (shipping the Qt libraries, allowing them to be replaced; the iOS App Store makes that hard).
- **libmpv** (LGPLv2.1+ or GPLv2+, depending on how mpv was built). A GPL build of mpv makes a combined binary GPL.
- **TagLib** (LGPLv2.1 / MPLv1.1).
- **JetBrains Mono** (SIL Open Font Licence).

This is a summary, not legal advice. Check the licences before distributing binaries, especially for mobile.

## Windows

Download the newest build from the [windows-latest release](https://github.com/whozdgt/Paraplay/releases/tag/windows-latest): **Paraplay-Setup.exe** installs it for your user (no administrator prompt), or unzip the portable zip anywhere and run `musicplayer.exe`. Windows may say the publisher is unknown the first time, because the files are not code-signed: choose More info, then Run anyway. Tagged releases carry the same two files.

It is the same player: your music folder, playlists, servers, accounts, friends, lyrics and Home page all work. Differences on Windows:

- The window is solid instead of frosted glass (Windows can't blur what is behind a window the way Hyprland can). Pick the background colour in Settings, Theme colours.
- Media keys (play/pause, next, previous, stop) work, even while another program has the focus. Windows' own volume pop-up does not show the song yet.
- Output goes through the system mixer (WASAPI shared mode), so "Bit-perfect output" can't change the sample rate Windows uses.
- To update, download the newer Paraplay-Setup.exe and run it over the old one; your settings stay. The in-app "Update now" button is Linux and Android only for now.
- The build is for Intel/AMD 64-bit PCs. On a Windows on ARM laptop (Snapdragon) it runs through Windows' built-in emulation.

It is built in GitHub Actions with MSYS2's MinGW toolchain (`.github/workflows/windows.yml`), so building it yourself is: install MSYS2, `pacman -S` the same packages the workflow lists, then `cmake -B build -G Ninja && cmake --build build`.

**Licence note for the Windows download:** it contains mpv and FFmpeg as built by MSYS2 (GPL), Qt and TagLib (LGPL) next to the MIT player. The files `LICENSE.txt` and `THIRD-PARTY.txt` in the download say so, and the source for all of it is public (this repository, and the MSYS2 package sources).
