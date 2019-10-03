import hljs from "highlight.js"
import "highlight.js/styles/github-gist.css"

export default() => {
  document.querySelectorAll("pre code[class]").forEach(code => {
    hljs.highlightBlock(code)
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
}
