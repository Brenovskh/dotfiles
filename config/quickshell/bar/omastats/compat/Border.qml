pragma Singleton
import QtQuick

// Minimal border specs: { width, color }.
QtObject {
  function none() { return { width: 0, color: "transparent" } }
  function controlSpec(state, foreground, accent) {
    var c = Qt.color(state === "focus" ? accent : foreground)
    var a = state === "focus" ? 0.9 : (state === "hover-cursor" ? 0.35 : 0.18)
    return { width: 1, color: Qt.rgba(c.r, c.g, c.b, a) }
  }
  function localOrSurfaceSpec(section, key, color, fallback, width) {
    return { width: width === undefined ? 1 : width, color: color }
  }
  function top(spec) { return spec ? spec.width : 0 }
  function bottom(spec) { return spec ? spec.width : 0 }
  function left(spec) { return spec ? spec.width : 0 }
  function right(spec) { return spec ? spec.width : 0 }
}
