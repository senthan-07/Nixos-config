import QtQuick
import Quickshell
import qs.services

// Region selector overlays, one per screen. They exist only while a capture
// session is running (plus a short fade-out), so every session gets a fresh
// frozen frame.
Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            id: slot
            required property ShellScreen modelData

            LazyLoader {
                active: Capture.overlayShown

                CaptureWindow {
                    targetScreen: slot.modelData
                }
            }
        }
    }
}
