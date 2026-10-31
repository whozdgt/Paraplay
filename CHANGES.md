# Drop 7: friends, public profiles and a profile preview
- **Friends** (sidebar, under Playlists): Activity, Find people, and Requests. Activity shows what the people you follow are playing right now (with the song's quality), what they played earlier, and the playlists they chose to share.
- **Public profiles:** open anyone's profile from Find people, Activity or Requests: picture, banner, bio, follower counts, shared playlists, and what they're listening to. Follow with one press; a Private profile gets a "Request" instead.
- **Public or Private:** your profile page now has a Public / Private switch. A Private profile keeps its bio, banner, playlists, counts and listening hidden from everyone except people you accept. Name, @username and picture stay visible so friends can find you. Accounts start Private.
- **Preview:** on your own profile page, Edit | Preview shows exactly what a stranger sees, built from what is saved. Nothing in it can be changed.
- **Your choices:** Appear in search, Show my playlists (only playlists you mark "Share on your profile"; the button sits beside a playlist's name), Show what I'm listening to (off by default), Show follower counts.
- **A friend's playlist:** their songs arrive as text only (title, artist, album, length). Every song you also own plays from your own copy, local or on any of your servers, at its own quality. Songs you don't have are greyed out. "Play all" plays the ones you have; "Save to my playlists" makes you a copy of them. No music file is ever uploaded or sent.
- **Block and report:** the "..." button on a profile. Blocking hides you both from each other and removes any follow; undo it under Requests. Reports go to the project owner only.
- Fixed: a dropped connection no longer signs you out when your session refreshes; only a refusal from the server does.
- **Needs a one-time database step before you update:** run `supabase/social.sql` in the Supabase SQL Editor (safe to run twice). It adds the social tables and tightens the older ones so nobody can read another person's profile, playlists or songs directly. Without it, saving your profile and syncing playlists will fail.
- Needs `cmake -B build` to be run again (new files), then `cmake --build build -j`.
- Not yet: Spotify and YouTube Music, WebDAV and plain web-folder sources, a Windows build.

# Drop 6: your own servers, updates, and the carousel back at full size
- Carousels are back to the full-width Cover Flow spread (the Drop 3 size). The playlist "+" tile is gone: press "New playlist" beside the Playlists heading instead.
- Searching Albums, Artists or Playlists is lighter: when you choose a result, only that cover stays loaded (with two plain frosted layers behind it) and the rest of the carousel is unloaded. Closing the search fans the carousel back out at that cover.
- Stream from your own server: Navidrome / Subsonic and Jellyfin. Sidebar → SOURCES → "Add a server…", or Settings → Servers. Original files, no transcoding. A cloud marks streamed songs and covers.
- Sources: "All sources", "This computer" and each server filter Songs, Albums and Artists (sidebar, or the chip beside the heading once you have a server).
- Servers are saved with a one-way sign-in token (Navidrome/Subsonic) or access token (Jellyfin), never your password, in a private file. Self-signed certificates are optional and pinned the first time you accept one.
- Song lists are cached per server, refreshed on start and every 4 hours, or press "Sync now".
- Updates: Settings → Updates. Checks GitHub for a newer release (switchable), shows "Update available" in the sidebar, and "Update now" builds and installs it for you, then "Restart".
- update.sh changed: `./update.sh --here` builds and installs this folder into ~/.local; `./update.sh [--tag vX.Y.Z]` fetches a release from GitHub. It no longer unpacks a tarball from ~/Downloads.
- Public repository with the MIT licence, a build check on every push, and releases published from tags.
- Needs `cmake -B build` to be run again (new files), then `cmake --build build -j`.
- Not yet: WebDAV and plain web-folder sources; Spotify; social features. Song lyrics (.lrc) are local-file only for now.
- Note: the sign-in details live in a private file (permissions 0600) rather than the system keyring, so the player stays free of extra dependencies. A keyring option can follow.

# Drop 5: profile picture and banner
- Profile page: click the picture or the banner (or the camera buttons) to change them. Drop an image file onto the window, or paste its path and press Enter, then Upload. Remove puts the blank picture back.
- Profile pictures: PNG, JPEG or WebP. The middle square is used and shrunk to 512 px, so uploads stay small and quick.
- Banners: PNG, JPEG, WebP or GIF. GIF banners are uploaded exactly as they are (up to 3 MB and 1200 x 600). Still banners are shrunk for you.
- Your picture also shows at the top of the sidebar.
- Pictures are downloaded once and kept in the cache, so nothing is fetched again each time. A GIF only loads while the profile page is showing and only plays while the window is in front.
- Delete account now removes your stored pictures first.
- Needs a one-time database step: run supabase/images.sql in the Supabase SQL Editor (safe to run twice).

# Drop 4: profiles
- Fixed: the playlist "+" tile no longer clips off screen; carousels keep their covers inside the view, and a few items stay close together.
- Fixed: choosing a search result now moves that cover to the FRONT OF THE STACK and keeps the stack open. Click the front cover to open it, or press Esc / the magnifier to fan the carousel back out.
- Profiles: click "Guest" at the top of the sidebar. Create an account or sign in with a username and password (no email). The profile page has display name, bio, who can see you (Private by default), appear in search, show playlists, sync, save, sync now, sign out, download my data, delete account.
- Playlists sync to your database automatically a few seconds after a change (newest edit wins). Each account keeps its own playlists on this computer; guest playlists are copied into your account the first time you sign in.
- Not yet: following/finding other people, public profile pages, report and block screens, profile pictures, syncing settings and artist photos.
