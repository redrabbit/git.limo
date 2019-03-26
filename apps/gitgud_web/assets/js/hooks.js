import React from "react"
import ReactDOM from "react-dom"

import {camelCase, upperFirst} from "lodash"

import hljs from "highlight.js"
import "highlight.js/styles/github-gist.css"

import {token} from "./auth"
import * as factory from "./components"

export default () => {
  document.querySelectorAll("article.message").forEach(flash => {
    flash.querySelector("button.delete").addEventListener("click", event => {
      flash.remove()
    })
  })

  document.querySelectorAll(".code .code-inner").forEach(block => hljs.highlightBlock(block))

  document.querySelectorAll("[data-react-class]").forEach(e => {
    const targetId = document.getElementById(e.dataset.reactTargetId)
    const targetDiv = targetId ? targetId : e
    const reactProps = e.dataset.reactProps ? atob(e.dataset.reactProps) : "{}"
    const reactElement = React.createElement(factory[upperFirst(camelCase(e.dataset.reactClass))], JSON.parse(reactProps))
    ReactDOM.render(reactElement, targetDiv)
  })

  if(token) {
    document.querySelectorAll("table.diff-table").forEach(diffTable => {
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
              ReactDOM.render(React.createElement(factory["CommitLineReview"], {...diffTable.dataset, ...event.currentTarget.dataset}), container);
              row.appendChild(column)
            }
            tr.nextSibling.querySelector("form [name='comment[body]']").focus()
          })
          origin = td
        } else {
          origin = td.previousElementSibling
        }
        td.addEventListener("mouseover", () => origin.classList.add("is-active"))
        td.addEventListener("mouseout", () => origin.classList.remove("is-active"))
      })
    })
  }
}
