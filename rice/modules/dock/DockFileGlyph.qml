import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components

// Icon for a file in the folder stack: a real thumbnail for images, the
// themed mime icon otherwise, and a tinted Material glyph as last resort.
Item {
    id: root

    property var file: null           // {name, path, dir}
    property real size: 48

    readonly property string ext: {
        const n = file ? String(file.name) : "";
        const i = n.lastIndexOf(".");
        return i > 0 ? n.slice(i + 1).toLowerCase() : "";
    }
    readonly property bool isImage: !!file && !file.dir && ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].indexOf(ext) >= 0
    readonly property var kind: {
        if (!file) return { icon: "text-x-generic", glyph: "draft" };
        if (file.dir) return { icon: "folder", glyph: "folder" };
        const map = [
            [["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif", "heic"], "image-x-generic", "image"],
            [["mp4", "mkv", "webm", "mov", "avi"], "video-x-generic", "movie"],
            [["mp3", "flac", "ogg", "opus", "wav", "m4a"], "audio-x-generic", "music_note"],
            [["pdf"], "application-pdf", "picture_as_pdf"],
            [["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"], "package-x-generic", "folder_zip"],
            [["deb", "rpm", "appimage", "exe", "msi"], "application-x-executable", "install_desktop"],
            [["iso", "img"], "media-optical", "album"],
            [["doc", "docx", "odt", "rtf"], "x-office-document", "description"],
            [["xls", "xlsx", "ods", "csv"], "x-office-spreadsheet", "table"],
            [["ppt", "pptx", "odp"], "x-office-presentation", "slideshow"],
            [["html", "htm"], "text-html", "html"],
            [["txt", "md", "log", "json", "nix", "qml", "js", "py", "sh", "c", "rs", "toml", "yaml"], "text-x-generic", "article"],
            [["torrent"], "application-x-bittorrent", "download"]
        ];
        for (const m of map) if (m[0].indexOf(ext) >= 0) return { icon: m[1], glyph: m[2] };
        return { icon: "text-x-generic", glyph: "draft" };
    }
    readonly property string themed: Quickshell.iconPath(kind.icon, true)

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        visible: root.isImage
        radius: root.size * 0.18
        color: Theme.surfaceHighest
        clip: true
        border.width: 2
        border.color: Theme.alpha(Theme.surfaceFg, 0.9)

        Image {
            id: thumb
            anchors.fill: parent
            anchors.margins: 2
            source: root.isImage ? "file://" + root.file.path : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    IconImage {
        anchors.centerIn: parent
        visible: !root.isImage && root.themed !== ""
        implicitSize: root.size
        source: root.themed
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: (!root.isImage && root.themed === "") || (root.isImage && thumb.status === Image.Error)
        radius: root.size * 0.24
        color: root.file && root.file.dir ? Theme.primaryContainer : Theme.secondaryContainer
        Icon {
            anchors.centerIn: parent
            text: root.kind.glyph
            size: root.size * 0.55
            fill: 1
            color: root.file && root.file.dir ? Theme.primaryContainerFg : Theme.secondaryContainerFg
        }
    }
}
