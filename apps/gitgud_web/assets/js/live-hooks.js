import hljs from "highlight.js"

function addCommitLineReviewInteract(table, cb) {
  table.querySelectorAll("tbody tr:not(.hunk) td.code").forEach(td => {
    let origin
    let tr = td.parentElement
    if(td.classList.contains("origin")) {
      td.querySelector("button").addEventListener("click", event => {
        if(tr.nextElementSibling && tr.nextElementSibling.classList.contains("inline-comments")) {
          const form = tr.nextElementSibling.querySelector("td .timeline .timeline-item:last-child .timeline-content .comment-form")
          const input = form.querySelector("input[phx-focus]") || form.querySelector("textarea")
          input.focus()
        } else  {
          let sibling = tr.previousElementSibling
          let hunk = -1
          let line = -1
          while(sibling) {
            line++
            if(sibling.classList.contains("hunk")) {
              hunk = parseInt(sibling.dataset.hunk)
            }
            sibling = sibling.previousElementSibling;
          }
          cb(hunk, line)
        }
      })
      origin = td
    } else {
      origin = td.previousElementSibling
    }
    tr.addEventListener("mouseover", () => origin.classList.add("is-active"))
    tr.addEventListener("mouseout", () => origin.classList.remove("is-active"))
  })
}

function highLightCode(table, lang) {
  const langDetect = hljs.getLanguage(lang)
  const highlightLine = (line) => {
    const result = langDetect ? hljs.highlight(lang, line.textContent, true, state) : hljs.highlightAuto(line.textContent)
    state = result.top
    line.innerHTML = result.value
  }

  let state
  let row = table.querySelector("tr.hunk")
  while(row) {
    row = row.nextElementSibling
    if(!row || row.classList.contains("hunk")) {
      state = undefined
      continue
    }
    const line = row.querySelector("td.code .code-inner:not(.highlight)")
    if(line) highlightLine(line)
  }
}

let Hooks = {}

Hooks.CommitDiffTable = {
  mounted() {
    const table = this.el
    const {lang, oid} = table.dataset
    addCommitLineReviewInteract(table, (hunk, line) => {
      this.pushEvent("add_review_form", {oid, hunk, line})
    })
    highLightCode(table, lang)
  }
}

export default Hooks