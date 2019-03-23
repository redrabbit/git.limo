import "phoenix_html"

import React from "react"
import ReactDOM from "react-dom"

import hljs from "highlight.js"
import "highlight.js/styles/github-gist.css"

import factory from "./react-factory"
import InlineCommentForm from "./components/InlineCommentForm"

import css from "../css/app.scss"

document.addEventListener("DOMContentLoaded", factory);
document.querySelectorAll(".code .code-inner").forEach(block => hljs.highlightBlock(block));

[...document.getElementsByClassName("message")].forEach(flash => {
  flash.querySelector("button.delete").addEventListener("click", event => {
    flash.remove()
  })
});

[...document.getElementsByClassName("diff-table")].forEach(diffTable => {
  diffTable.querySelectorAll("tbody tr:not(.hunk) td.code").forEach(td => {
    let origin
    if(td.classList.contains("origin")) {
      td.querySelector("button").addEventListener("click", event => {
        let tr = td.parentElement
        if(!tr.nextSibling || !tr.nextSibling.classList.contains("inline-comments")) {
          let row = diffTable.insertRow(tr.rowIndex+1);
          row.classList.add("inline-comments")
          let column = document.createElement("td")
          column.colSpan = 4
          let container = column.appendChild(document.createElement("div"))
          container.classList.add("inline-comment-form")
          ReactDOM.render(React.createElement(InlineCommentForm, {...diffTable.dataset, ...event.currentTarget.dataset}), container);
          row.appendChild(column)
        }
        tr.nextSibling.querySelector("[name='comment[body]']").focus()
      })
      origin = td
    } else {
      origin = td.previousElementSibling
    }
    td.addEventListener("mouseover", () => origin.classList.add("is-active"))
    td.addEventListener("mouseout", () => origin.classList.remove("is-active"))
  })
});
