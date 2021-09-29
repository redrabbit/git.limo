import hljs from "highlight.js"
import "highlight.js/styles/github.css"

export default() => {
  document.querySelectorAll("pre code[class]").forEach(code => {
    hljs.highlightElement(code)
  })

  document.querySelectorAll("table.blob-table").forEach(table => {
    const {lang} = table.dataset
    const langDetect = hljs.getLanguage(lang)
    const highlight = (line) => {
      const result = langDetect ? hljs.highlight(line.textContent, {language: lang, ignoreIllegals: true}, state) : hljs.highlightAuto(line.textContent)
      state = result.top
      line.innerHTML = result.value
    }
    let state
    table.querySelectorAll("td.code .code-inner:not(.nohighlight)").forEach(highlight)
  })
}
