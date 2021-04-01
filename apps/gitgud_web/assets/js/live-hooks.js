import hljs from "highlight.js"

function highlightTable(table) {
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
      const result = langDetect ? hljs.highlight(lang, line.textContent, true, state) : hljs.highlightAuto(line.textContent)
      state = result.top
      line.innerHTML = result.value
    }
  }
}

let Hooks = {}

Hooks.CommitDiffTable = {
  mounted() {
    highlightTable(this.el)
    this.handleEvent("delete_comment", ({comment_id}) => {
      const commentContainerElement = this.el.querySelector(`#comment-${comment_id}-container`)
      if(commentContainerElement) {
        const timelineContainerElement = commentContainerElement.parentElement
        if(timelineContainerElement.childElementCount > 2) {
          timelineContainerElement.removeChild(commentContainerElement)
        } else {
          this.el.deleteRow(timelineContainerElement.closest("tr.inline-comments").rowIndex)
        }
      }
    })
  },
  updated() {
    highlightTable(this.el)
  }
}

export default Hooks