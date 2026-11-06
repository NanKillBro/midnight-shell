pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components.misc

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    // Apps that expose in-app volume control over MPRIS. Sources not in this list
    // fall back to per-stream PipeWire volume control. Add new entries here.
    readonly property list<string> appVolumePlayers: [ "Spotify", "Fastpotify" ]

    // Dedup key for progressive metadata (e.g. mpv-mpris/yt-dlp player fills title then artist later).
    property string lastNowPlayingKey: ""

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.values.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function supportsAppVolume(player: MprisPlayer): bool {
        if (!player)
            return false;
        const identity = root.getIdentity(player).toLowerCase();
        return root.appVolumePlayers.some(id => identity.includes(id.toLowerCase()));
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            // Fallback for youtube
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    // Quickshell only emits postTrackChanged when trackid/url/title change, so late
    // artist updates (common with mpv-mpris + yt-dlp player) never retrigger it. Watch
    // title/artist too and toast once both are usable.
    function maybeToastNowPlaying(): void {
        if (!GlobalConfig.utilities.toasts.nowPlaying)
            return;

        const player = root.active;
        if (!player)
            return;

        const title = player.trackTitle ?? "";
        const artist = player.trackArtist ?? "";
        if (!title || !artist)
            return;

        const key = `${getIdentity(player)}\0${player.uniqueId}\0${title}\0${artist}`;
        if (key === lastNowPlayingKey)
            return;

        lastNowPlayingKey = key;
        Toaster.toast(Tr.tr("Now playing"), Tr.trCtx("%1 - %2", "track artist and title").arg(artist).arg(title), "music_note");
    }

    // The Lyrics service is the single source of truth for both the dashboard
    // media tab and the desktop lyrics overlay. Keep it in sync here so neither
    // view has to call setTrack/clearTrack itself: a view that is created late
    // (or an overlay whose Loader finished before the metadata arrived) must
    // not be the only thing that can kick off a load.
    //
    // Views acquire/release a consumer slot so lyrics are only fetched while
    // something can actually display them. The first consumer forces a load
    // for the current track; metadata signals keep it up to date afterwards.
    property int lyricsConsumers: 0

    function syncLyrics(force): void {
        if (!force && lyricsConsumers <= 0)
            return;
        const player = root.active;
        if (player && (player.trackArtist || player.trackTitle))
            Lyrics.setTrack(player.trackArtist, player.trackTitle, player.trackAlbum, player.length);
        else
            Lyrics.clearTrack();
    }

    function acquireLyrics(): void {
        lyricsConsumers++;
        if (lyricsConsumers === 1)
            syncLyrics(true);
    }

    function releaseLyrics(): void {
        lyricsConsumers = Math.max(0, lyricsConsumers - 1);
    }

    onActiveChanged: {
        lastNowPlayingKey = "";
        syncLyrics();
    }

    Component.onCompleted: syncLyrics()

    Connections {
        function onPostTrackChanged(): void {
            root.maybeToastNowPlaying();
            root.syncLyrics();
        }

        function onTrackTitleChanged(): void {
            root.maybeToastNowPlaying();
            root.syncLyrics();
        }

        function onTrackArtistChanged(): void {
            root.maybeToastNowPlaying();
            root.syncLyrics();
        }

        function onTrackAlbumChanged(): void {
            root.syncLyrics();
        }

        function onLengthChanged(): void {
            root.syncLyrics();
        }

        target: root.active
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
