import "phoenix_html"

import css from "../css/app.scss"

import liveView from "./live-view"
import factory from "./react-factory"

[...document.getElementsByClassName("message")].forEach(flash => {
  flash.querySelector("button.delete").addEventListener("click", event => {
    flash.remove()
  })
})

liveView.connect()

document.addEventListener("DOMContentLoaded", factory)
