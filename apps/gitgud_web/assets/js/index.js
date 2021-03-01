import "phoenix_html"

import hooks from "./hooks"

import liveSocket from "./live-socket"

import "../css/app.scss"

liveSocket.connect()

document.addEventListener("DOMContentLoaded", () => {
  hooks.forEach(hook => hook())
})
