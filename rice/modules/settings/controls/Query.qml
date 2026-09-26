import QtQuick
import Quickshell.Io

// One-shot command runner with collected output.
//   Query { id: q; onFinished: (out, code) => … }   q.start(["nmcli", …])
// Calls made while a run is in progress are queued and executed in order.
Item {
    id: root

    property bool busy: proc.running || queue.length > 0
    property var queue: []
    signal finished(string out, int code)

    function start(argv) {
        if (proc.running) {
            queue = [...queue, argv];
            return;
        }
        proc.command = argv;
        proc.running = true;
    }

    Process {
        id: proc
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: code => {
            root.finished(code === 0 ? out.text : (err.text || out.text), code);
            if (root.queue.length) {
                const next = root.queue[0];
                root.queue = root.queue.slice(1);
                Qt.callLater(() => root.start(next));
            }
        }
    }
}
