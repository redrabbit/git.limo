import hljs from "highlight.js"

function highlightTable(table) {
  const lang = table.dataset.lang
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
    highlightTable(this.el)
  },
  updated() {
    highlightTable(this.el)
  }
}

export default Hooks