import React from "react"
import ReactDOM from "react-dom"

import {camelCase, upperFirst} from "lodash"

import hljs from "highlight.js"
import "highlight.js/styles/github-gist.css"

import moment from "moment"

import * as factory from "./components"
import {BlobTableHeader, CommitLineReview, CommitSignature, TreeTable} from "./components"

export default () => {
  document.querySelectorAll("[data-react-class]").forEach(e => {
    const targetId = document.getElementById(e.dataset.reactTargetId)
    const targetDiv = targetId ? targetId : e
    const reactProps = e.dataset.reactProps ? atob(e.dataset.reactProps) : "{}"
    const reactElement = React.createElement(factory[upperFirst(camelCase(e.dataset.reactClass))], JSON.parse(reactProps))
    ReactDOM.render(reactElement, targetDiv)
  })

  document.querySelectorAll("article.message").forEach(flash => {
    flash.querySelector("button.delete").addEventListener("click", event => {
      flash.remove()
    })
  })

  document.querySelectorAll("pre code[class]").forEach(code => {
    hljs.highlightBlock(code)
  })

  document.querySelectorAll("nav.level .breadcrumb").forEach(breadcrumb => {
    const level = breadcrumb.closest(".level")
    const levelRight = level.querySelector(".level-right")
    let fromIndex = 2
    let ellipsis
    let truncate = levelRight ? levelRight.offsetLeft + levelRight.offsetWidth - level.offsetWidth
                              : breadcrumb.offsetLeft + breadcrumb.offsetWidth - level.offsetWidth
    while(truncate > 0) {
      const items = breadcrumb.querySelectorAll("ul li")
      const item = items[fromIndex]
      if(!ellipsis) {
        const oldWidth = item.offsetWidth
        ellipsis = item.querySelector("a")
        ellipsis.dataset.tooltip = ellipsis.text
        ellipsis.innerHTML = "&hellip;"
        ellipsis.classList.add("tooltip")
        truncate -= oldWidth - item.offsetWidth
        fromIndex += 1
      } else {
        ellipsis.href = item.querySelector("a").href
        ellipsis.dataset.tooltip = `${ellipsis.dataset.tooltip}/${item.querySelector("a").text}`
        truncate -= item.offsetWidth
        item.parentNode.removeChild(item)
      }
    }
  })

  document.querySelectorAll("table.tree-table").forEach(table => {
    const {repoId, commitOid, treePath} = table.dataset
    TreeTable.fetchTreeEntriesWithCommit(repoId, commitOid, treePath)
      .then(response => {
        const latestCommitEdge = response.node.object.treeEntriesWithLastCommit.edges.reduce((acc, edge) => {
          if(edge.node.commit.timestamp > acc.node.commit.timestamp) {
            return edge
          } else {
            return acc
          }
        })
        const {commit} = latestCommitEdge.node
        const timestamp = moment.utc(commit.timestamp)
        const messageTitle = commit.message.split("\n", 1)[0].trim()
        let header = table.createTHead()
        let tr = header.insertRow()
        let td = tr.insertCell(0)
        td.colSpan = 2
        ReactDOM.render(React.createElement(CommitSignature, {author: commit.author, committer: commit.committer}), td)
        let commitLink = document.createElement("a")
        commitLink.href = commit.url
        commitLink.classList.add("has-text-grey")
        commitLink.appendChild(document.createTextNode(messageTitle))
        td.innerHTML += "&nbsp;"
        td.append(commitLink)
        td = tr.insertCell(1)
        td.classList.add("has-text-right")
        td.classList.add("has-text-grey")
        let time = document.createElement("time")
        time.classList.add("tooltip")
        time.setAttribute("data", timestamp.format())
        time.dataset.tooltip = timestamp.format()
        time.innerHTML = timestamp.fromNow()
        td.append(time)
        response.node.object.treeEntriesWithLastCommit.edges.forEach(edge => {
          const {treeEntry, commit} = edge.node
          const timestamp = moment.utc(commit.timestamp)
          const messageTitle = commit.message.split("\n", 1)[0].trim()
          td = table.querySelector(`tr td[data-oid="${treeEntry.oid}"]`)
          td.colSpan = 1
          tr = td.parentElement
          td = tr.insertCell(1)
          commitLink = document.createElement("a")
          commitLink.href = commit.url
          commitLink.classList.add("has-text-grey")
          commitLink.appendChild(document.createTextNode(messageTitle))
          td.append(commitLink)
          td = tr.insertCell(2)
          td.classList.add("has-text-right")
          td.classList.add("has-text-grey")
          time = document.createElement("time")
          time.classList.add("tooltip")
          time.setAttribute("data", timestamp.format())
          time.dataset.tooltip = timestamp.format()
          time.innerHTML = timestamp.fromNow()
          td.append(time)
        })
        table.classList.remove("loading")
      })
  })

  document.querySelectorAll("table.blob-table").forEach(table => {
    const {lang} = table.dataset
    const langDetect = hljs.getLanguage(lang)
    const highlight = (line) => {
      const result = langDetect ? hljs.highlight(lang, line.textContent, true, state) : hljs.highlightAuto(line.textContent)
      state = result.top
      line.innerHTML = result.value
    }
    let state
    if(table.classList.contains("diff-table")) {
      let row = table.querySelector("tr.hunk")
      while(row) {
        row = row.nextElementSibling
        if(!row || row.classList.contains("hunk")) {
          state = undefined
          continue
        }
        const line = row.querySelector("td.code .code-inner:not(.highlight)")
        if(line) highlight(line)
      }
    } else {
      table.querySelectorAll("td.code .code-inner:not(.nohighlight)").forEach(highlight)
    }
  })

  const blob = document.getElementById("blob-commit")
  if(blob) {
    const {repoId, commitOid, blobPath} = blob.dataset
    BlobTableHeader.fetchTreeEntryWithCommit(repoId, commitOid, blobPath)
      .then(response => {
        const {commit} = response.node.object.treeEntryWithLastCommit
        const container = document.createElement("div")
        blob.prepend(container)
        ReactDOM.render(React.createElement(BlobTableHeader, {commit: commit}), container)
        blob.classList.remove("loading")
      })
  }

  const diff = document.getElementById("diff-commit")
  if(diff) {
    const {repoId, commitOid} = diff.dataset
    CommitLineReview.subscribeNewLineReviews(repoId, commitOid, {
      onNext: response => {
        const {id, blobOid, hunk, line} = response.commitLineReviewCreate
        let table = document.querySelector(`table.diff-table[data-blob-oid=${blobOid}]`)
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
            tr.nextElementSibling.querySelector(".comment-form:last-child form [name='comment[body]']").focus()
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
