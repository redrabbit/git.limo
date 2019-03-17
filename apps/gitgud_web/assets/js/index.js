import "phoenix_html"

import css from "../css/app.scss"

import factory from "./react-factory"

[...document.getElementsByClassName("message")].forEach(flash => {
  flash.querySelector("button.delete").addEventListener("click", event => {
    flash.remove()
  })
})

document.addEventListener("DOMContentLoaded", factory)
