export default () => {
  const commits = document.querySelectorAll(".commit-oid")
  for(let commit of commits) {
    commit.dataset.tooltip = "Copy to clipboard"
    commit.addEventListener("click", event => {
      let copyInput = document.createElement("input")
      copyInput.value = commit.querySelector("span").textContent
      document.body.appendChild(copyInput)
      copyInput.select()
      document.execCommand("copy")
      copyInput.remove()
      commit.dataset.tooltip = "Copied"
    })
    commit.addEventListener("mouseleave", event => {
      commit.dataset.tooltip = "Copy to clipboard"
    })
  }
}

