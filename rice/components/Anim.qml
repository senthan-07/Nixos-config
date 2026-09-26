import QtQuick
import qs.config

NumberAnimation {
    duration: Motion.duration.medium
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve.standard
}
