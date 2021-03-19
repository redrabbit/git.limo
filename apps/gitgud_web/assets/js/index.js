import "phoenix_html"

import hooks from "./hooks"

import "../css/app.scss"

document.addEventListener("DOMContentLoaded", () => {
  hooks.forEach(hook => hook())
})
