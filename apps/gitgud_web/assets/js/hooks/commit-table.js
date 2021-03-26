import React from "react"
import ReactDOM from "react-dom"

import {currentUser} from "../auth"

import {CommitLineReview} from "../components"

export default () => {
  /*
  const commitStats = document.getElementById("commit-stats")
  if(commitStats) {
    const {repoId, commitOid} = commitStats.dataset
    CommitLineReview.fetchLineReviews(repoId, commitOid).then(response => {
      response.node.object.lineReviews.edges.forEach(({node}) => {
        const {id, blobOid, hunk, line} = node
        let table = document.querySelector(`table.commit-table[data-blob-oid="${blobOid}"]`)
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
          ReactDOM.render(React.createElement(CommitLineReview, {
            id, 
            repoId: repoId,
            commitOid: commitOid,
            blobOid: blobOid,
            hunk: hunk,
            line: line,
            comments: node.comments.edges.map(edge => edge.node)
          }), row)
        }
      })
    })

    CommitLineReview.subscribeNewLineReviews(repoId, commitOid, {
      onNext: response => {
        const {id, blobOid, hunk, line, comments} = response.commitLineReviewCreate
        let table = document.querySelector(`table.commit-table[data-blob-oid="${blobOid}"]`)
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
          ReactDOM.render(React.createElement(CommitLineReview, {
            id: id,
            repoId: repoId,
            commitOid: commitOid,
            blobOid: blobOid,
            hunk: hunk,
            line: line,
            comments: comments.edges.map(edge => edge.node)
          }), row)
        }
      },
      onError: error => console.error(error)
    })

    document.querySelectorAll("table.commit-table").forEach(table => {
      const {blobOid} = table.dataset
      table.querySelectorAll("tbody tr:not(.hunk) td.code").forEach(td => {
        let origin
        if(td.classList.contains("origin")) {
          td.querySelector("button").addEventListener("click", event => {
            let tr = td.parentElement
            if(!tr.nextElementSibling || !tr.nextElementSibling.classList.contains("inline-comments")) {
              let row = table.insertRow(tr.rowIndex+1);
              row.classList.add("inline-comments")
              const {hunk, line} = event.currentTarget.dataset
              ReactDOM.render(React.createElement(CommitLineReview, {
                repoId: repoId,
                commitOid: commitOid,
                blobOid: blobOid,
                hunk: Number(hunk),
                line: Number(line)
              }), row)
            }
            let commentBody = tr.nextElementSibling.querySelector(".comment-form:last-child form [name='comment[body]']")
            if(commentBody) commentBody.focus()
          })
          origin = td
        } else {
          origin = td.previousElementSibling
        }
        if(currentUser) {
          td.addEventListener("mouseover", () => origin.classList.add("is-active"))
          td.addEventListener("mouseout", () => origin.classList.remove("is-active"))
        }
      })
    })
  }
  */
}
