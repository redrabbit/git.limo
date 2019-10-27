import React from "react"
import ReactDOM from "react-dom"

import {CommitLineReview} from "../components"

export default () => {
  const diff = document.getElementById("diff")
  if(diff) {
    const {repoId, commitOid} = diff.dataset
    CommitLineReview.subscribeNewLineReviews(repoId, commitOid, {
      onNext: response => {
        const {id, blobOid, hunk, line} = response.commitLineReviewCreate
        let table = document.querySelector(`table.diff-table[data-blob-oid="${blobOid}"]`)
        let tr = table.querySelectorAll("tbody tr.hunk")[hunk]
        for(let i = 0; i <= line; i++) {
          tr = tr.nextElementSibling
          if(tr.classList.contains("inline-comments")) {
            tr = tr.nextElementSibling
          }
        }
        if(!tr.nextElementSibling || !tr.nextElementSibling.classList.contains("inline-comments")) {
          let row = table.insertRow(tr.rowIndex+1)
          row.classList.add("inline-comments")
          ReactDOM.render(React.createElement(CommitLineReview, {reviewId: id}), row)
        }
      }
    })

    document.querySelectorAll("table.diff-table").forEach(table => {
      const {blobOid} = table.dataset
      table.querySelectorAll("tbody tr:not(.hunk) td.code").forEach(td => {
        let origin
        if(td.classList.contains("origin")) {
          td.querySelector("button").addEventListener("click", event => {
            let tr = td.parentElement
            if(!tr.nextElementSibling || !tr.nextElementSibling.classList.contains("inline-comments")) {
              let row = table.insertRow(tr.rowIndex+1);
              row.classList.add("inline-comments")
              ReactDOM.render(React.createElement(CommitLineReview, {...{repoId: repoId, commitOid: commitOid, blobOid: blobOid}, ...event.currentTarget.dataset}), row)
            }
            let commentBody = tr.nextElementSibling.querySelector(".comment-form:last-child form [name='comment[body]']")
            if(commentBody) commentBody.focus()
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
