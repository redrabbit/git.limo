import React from "react"
import ReactDOM from "react-dom"

import {CommitSignature, TreeTable} from "../components"

import moment from "moment"

export default () => {
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
        const thead = table.tHead
        let tr = thead.rows[0]
        let td, commitLink, time
        if(tr.cells.length == 1) {
          td = tr.cells[0]
          td.colSpan = 2
          ReactDOM.render(React.createElement(CommitSignature, {author: commit.author, committer: commit.committer}), td)
          commitLink = document.createElement("a")
          commitLink.href = commit.url
          commitLink.classList.add("has-text-dark")
          commitLink.appendChild(document.createTextNode(messageTitle))
          td.innerHTML += "&nbsp;"
          td.append(commitLink)
          td = tr.insertCell(1)
          td.classList.add("has-text-right")
          td.classList.add("has-text-dark")
          time = document.createElement("time")
          time.classList.add("tooltip")
          time.setAttribute("data", timestamp.format())
          time.dataset.tooltip = timestamp.format()
          time.innerHTML = timestamp.fromNow()
          td.append(time)
        }

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
          commitLink.classList.add("has-text-dark")
          commitLink.appendChild(document.createTextNode(messageTitle))
          td.append(commitLink)
          td = tr.insertCell(2)
          td.classList.add("has-text-right")
          td.classList.add("has-text-dark")
          time = document.createElement("time")
          time.classList.add("tooltip")
          time.setAttribute("data", timestamp.format())
          time.dataset.tooltip = timestamp.format()
          time.innerHTML = timestamp.fromNow()
          td.append(time)
        })
      })
  })

}
