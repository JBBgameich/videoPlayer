/*
* Copyright (C) 2014-2015 Leszek Lesner <leszek@zevenos.com>
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) version 3, or any
* later version accepted by the membership of KDE e.V. (or its
* successor approved by the membership of KDE e.V.), which shall
* act as a proxy defined in Section 6 of version 3 of the license.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library.  If not, see <http://www.gnu.org/licenses/>.
*
*/

import QtQuick 2.1
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.0 as Controls
import QtMultimedia 5.7
import org.kde.kirigami 2.0 as Kirigami
import org.nemomobile.mpris 1.0

import "helper/timeFormat.js" as TimeHelper
import "helper/db.js" as DB

Kirigami.Page {
	leftPadding: 0
	rightPadding: 0
	bottomPadding: 0
	topPadding: 0

	title: {
		if (title != "")
			return title
		else if (streamTitle != "")
			return streamTitle
		else
			return streamUrl
	}

	Component.onCompleted: {
		// Automaticly start playing
		videoWindow.play()
	}

	onStreamUrlChanged: {
		// TODO: maybe youtube or other url checks
		videoWindow.source = streamUrl
		// Correct Page title, this is just needed to work around a bug, maybe I've done this bad
		videoPlayerPage.title = mainWindow.streamTitle
		// Write into history database
		DB.addHistory(streamUrl, videoPlayerPage.title)
		// Don't forgt to write it to the List aswell
		mainWindow.add2History(streamUrl, videoPlayerPage.text)
	}

	id: videoPlayerPage

	property string originalUrl: mainWindow.originalUrl
	property string streamUrl: mainWindow.streamUrl
	property bool isYtUrl: mainWindow.isYtUrl
	property string streamTitle: mainWindow.streamTitle
	property string artist: videoWindow.metaData.albumArtist ? videoWindow.metaData.albumArtist : ""
	property int subtitlesSize: mainWindow.subtitlesSize
	property bool boldSubtitles: mainWindow.boldSubtitles
	property string subtitlesColor: mainWindow.subtitlesColor
	property bool enableSubtitles: mainWindow.enableSubtitles
	property variant currentVideoSub: []
	property string url720p: mainWindow.url720p
	property string url480p: mainWindow.url480p
	property string url360p: mainWindow.url360p
	property string url240p: mainWindow.url240p
	property string ytQual: mainWindow.ytQual
	property bool autoplay: mainWindow.autoplay

	actions {
		main: Kirigami.Action {
			text: "Play / Pause"
			iconName: {
				if (videoWindow.playbackState != MediaPlayer.PlayingState)
					return "media-playback-start"
				else
					return "media-playback-pause"
			}
			onTriggered: {
				if (videoWindow.playbackState != MediaPlayer.PlayingState)
					videoWindow.play()
				else
					videoWindow.pause()
			}
			shortcut: "Space"
		}
		left: Kirigami.Action {
			text: "Fullscreen"
			iconName: "view-fullscreen"
			onTriggered: toggleControls()
		}
		right: Kirigami.Action {
			text: "Stop"
			iconName: "media-playback-stop"
			onTriggered: {
				videoWindow.stop()
				pageStack.pop()
			}
		}
	}

	Rectangle {
		anchors.fill: parent
		color: "black"
	}

	Kirigami.Icon {
		id: onlyAudioIcon
		source: "audio-x-generic"
		anchors.centerIn: parent
		width: parent.width / 2
		height: width
		visible: !videoWindow.hasVideo
	}

	function showControls() {
		timeLine.visible = true
		timeLineLbl.visible = true
		controlsVisible = true
	}

	function hideControls() {
		timeLine.visible = false
		timeLineLbl.visible = false
		globalDrawer.drawerOpen = false
		applicationWindow().controlsVisible = false
	}

	function toggleControls() {
		if (timeLine.visible && applicationWindow().controlsVisible)
			hideControls()
		else if (!timeLine.visible && !applicationWindow().controlsVisible)
			showControls()
	}

	Video {
		id: videoWindow
		anchors.fill: parent
		onDurationChanged: timeLine.to = duration / 1000
		onPositionChanged: timeLine.value = position / 1000

		MouseArea {
			anchors.fill: parent
			onClicked: toggleControls()
		}

		onPaused: {
			mprisPlayer.playbackStatus = Mpris.Paused
		}
		onPlaying: {
			mprisPlayer.playbackStatus = Mpris.Playing

			var metadata = mprisPlayer.metadata
			metadata[Mpris.metadataToString(Mpris.Title)] = videoPlayerPage.title // String
			mprisPlayer.metadata = metadata
		}

		onStopped: {
			showControls()
			mprisPlayer.playbackStatus = Mpris.Stopped
			pageStack.pop(pageStack.lastItem)
		}
	}

	MprisPlayer {
		id: mprisPlayer

		serviceName: "llsvplayer"

		// Mpris2 Root Interface
		identity: "LLs Video Player"
		supportedUriSchemes: ["file"]
		supportedMimeTypes: ["audio/x-wav", "audio/x-vorbis+ogg"]

		// Mpris2 Player Interface
		canControl: true

		canGoNext: false
		canGoPrevious: false
		canPause: playbackStatus == Mpris.Playing
		canPlay: playbackStatus != Mpris.Playing
		canSeek: true

		playbackStatus: Mpris.Stopped
		loopStatus: Mpris.None
		shuffle: false
		volume: 1

		onPauseRequested: videoWindow.pause()
		onPlayRequested: videoWindow.play()
		onPlayPauseRequested: {
			if (videoWindow.playbackState != MediaPlayer.PlayingState)
					videoWindow.play()
				else
					videoWindow.pause()
		}
		onStopRequested: {
			videoWindow.stop()
			pageStack.pop()
		}
		onSeekRequested: {
			videoWindow.seek(offset)
			emitSeeked()
		}
		onSetPositionRequested: {
			videoWindow.position = position
			emitSeeked()
		}
		onOpenUriRequested: videoWindow.source(url)
	}

	footer: Row {
		Controls.Slider {
			id: timeLine
			from: 1
			width: parent.width - timeLineLbl.width
			onPressedChanged: {
				if (!pressed) {
					if (videoWindow.seekable) {
						videoWindow.seek(value * 1000)
					}
				}
			}
		}

		Controls.Label {
			id: timeLineLbl
			text: TimeHelper.formatTime(
					  timeLine.value) + "/" + TimeHelper.formatTime(
					  timeLine.maximumValue)
		}
	}
}
