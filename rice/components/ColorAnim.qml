import QtQuick
import qs.config

ColorAnimation {
    duration: Motion.duration.short
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.curve.standard
}
