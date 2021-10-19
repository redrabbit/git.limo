import hljs from "highlight.js"

import cloneRepo from "./hooks/clone-repo"
import treeBreadcrumb from "./hooks/tree-breadcrumb"

function highlightBlobTable(table) {
  const {lang} = table.dataset
  const langDetect = hljs.getLanguage(lang)
  const highlight = (line) => {
    const result = langDetect ? hljs.highlight(line.textContent, {language: lang, ignoreIllegals: true}, state) : hljs.highlightAuto(line.textContent)
    state = result.top
    line.innerHTML = result.value
  }
  let state
  table.querySelectorAll("td.code .code-inner:not(.nohighlight)").forEach(highlight)
}

function highlightDiffTable(table) {
  const lang = table.dataset.lang
  const langDetect = hljs.getLanguage(lang)

  let state
  let row = table.querySelector("tr.hunk")
  while(row) {
    row = row.nextElementSibling
    if(!row || row.classList.contains("hunk")) {
      state = undefined
      continue
    }
    const line = row.querySelector("td.code .code-inner:not(.highlight)")
    if(line) {
      const result = langDetect ? hljs.highlight(line.textContent, {language: lang, ignoreIllegals: true}, state) : hljs.highlightAuto(line.textContent)
      state = result.top
      line.innerHTML = result.value
    }
  }
}

function moveToTable(review, table, oid, hunk, line) {
    const button = table.querySelector(`button[phx-value-oid="${oid}"][phx-value-hunk="${hunk}"][phx-value-line="${line}"]`)
    const tableRow = table.insertRow(button.parentNode.parentNode.rowIndex + 1 )
    tableRow.parentElement.replaceChild(review, tableRow)
}

function updateCounter(oid, callback) {
  const tableRow = document.getElementById(`blob-${oid}`)
  if(tableRow.cells.length > 1) {
    const span = tableRow.cells[1].querySelector("a span:last-child")
    const count = callback(parseInt(span.textContent))
    if(count > 0) {
      span.textContent = count
    } else {
      tableRow.cells[0].colSpan = 2
      tableRow.deleteCell(1)
    }
  } else {
    const count = callback(0)
    if(count > 0) {
      tableRow.cells[0].removeAttribute("colspan")
      const td = tableRow.insertCell(1)
      td.classList.add("has-text-right")
      const link = document.createElement("a")
      link.href = `#${oid}`
      link.classList.add("button", "is-small", "is-white")
      const icon = document.createElement("span")
      icon.classList.add("icon")
      const i = document.createElement("i")
      i.classList.add("fa", "fa-comment-alt")
      const span = document.createElement("span")
      span.textContent = count
      icon.appendChild(i)
      link.appendChild(icon)
      link.appendChild(span)
      td.appendChild(link)
    }
  }
}

let Hooks = {}

Hooks.BranchSelect = {
}

Hooks.TreeBreadcrumb = {
  mounted() { treeBreadcrumb() },
  updated() { treeBreadcrumb() }
}

Hooks.BlobContentTable = {
  mounted() { highlightBlobTable(this.el) },
  updated() { highlightBlobTable(this.el) }
}

Hooks.CloneRepo = {
  mounted() { cloneRepo() }
}

Hooks.CommitDiff = {
  mounted() {
    this.handleEvent("add_comment", ({comment_id}) => {
      setTimeout(() => {
        const comment = this.el.querySelector(`#review-comment-${comment_id}`)
        const table = comment.closest("table")
        updateCounter(table.id, c => c + 1)
      }, 300)
    })

    this.handleEvent("delete_comment", ({comment_id}) => {
      const comment = this.el.querySelector(`#review-comment-${comment_id}`)
      const table = comment.closest("table")
      const review = comment.parentElement
      if(review.childElementCount > 1) {
        review.removeChild(comment)
      } else {
        table.deleteRow(review.closest("tr.inline-comments").rowIndex)
      }
      updateCounter(table.id, c => c - 1)
    })

    this.handleEvent("delete_review_form", ({oid, hunk, line}) => {
      const table = document.getElementById(oid)
      const form = this.el.querySelector(`#review-${oid}-${hunk}-${line}-form`)
      table.deleteRow(form.rowIndex)
    })
  }
}

Hooks.CommitDiffTable = {
  mounted() { highlightDiffTable(this.el) },
  updated() { highlightDiffTable(this.el) }
}

Hooks.CommitDiffDynamicForms = {
  updated() {
    this.el.childNodes.forEach(form => {
      const [oid, hunk, line] = form.id.split("-").slice(1, 4)
      moveToTable(form, document.getElementById(oid), oid, hunk, line)
    })
  }
}

Hooks.CommitDiffDynamicReviews = {
  updated() {
    this.el.childNodes.forEach(review => {
      const [oid, hunk, line] = review.id.split("-").slice(1)
      moveToTable(review, document.getElementById(oid), oid, hunk, line)
    })
  }
}

Hooks.IssueFeed = {
  mounted() {
    this.handleEvent("delete_comment", ({comment_id}) => {
      const comment = this.el.querySelector(`#issue-comment-${comment_id}`)
      comment.parentElement.removeChild(comment)
    })
  }
}

Hooks.CommentForm = {
  mounted() {
    const textarea = this.el.querySelector("textarea")
    if(textarea.autofocus) {
      const cursorPos = textarea.value.length
      textarea.setSelectionRange(cursorPos, cursorPos)
    }
  }
}

export default Hooks