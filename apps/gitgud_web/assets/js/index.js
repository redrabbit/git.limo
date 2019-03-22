import "phoenix_html"

import hljs from "highlight.js"
import "highlight.js/styles/github-gist.css"

import factory from "./react-factory"

import css from "../css/app.scss"


[...document.getElementsByClassName("message")].forEach(flash => {
  flash.querySelector("button.delete").addEventListener("click", event => {
    flash.remove()
  })
})

document.addEventListener("DOMContentLoaded", factory)
document.querySelectorAll(".code .code-inner").forEach(block => hljs.highlightBlock(block))
