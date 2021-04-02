import {IssueLabel} from "../components"

export default () => {
  /*
  document.querySelectorAll(".issue-label-select").forEach(container => {
    let select = container.querySelector("select")
    select.parentNode.style.display = "none"
    const control = container.querySelector(".control")
    const options = Array.apply(null, select.options).map(option => ({id: option.value, name: option.text, color: option.dataset.color}))
    options.forEach(label => {
      let button = document.createElement("p")
      button.style.backgroundColor = `#${label.color}`
      button.classList.add("button")
      button.classList.add("issue-label")
      button.classList.add("edit")
      button.classList.add(IssueLabel.textClass(label.color))
      button.dataset.labelId = label.id
      let iconContainer = document.createElement("span")
      iconContainer.classList.add("icon")
      iconContainer.classList.add("is-small")
      iconContainer.classList.add("is-pulled-right")
      let icon = document.createElement("i")
      icon.classList.add("fa")
      icon.classList.add("fa-minus")
      iconContainer.appendChild(icon)
      button.appendChild(iconContainer)
      button.appendChild(document.createTextNode(label.name))
      button.addEventListener("click", () => {
        let option = select.options[options.findIndex(option => option.id == button.dataset.labelId)]
        if(!button.classList.contains("is-active")) {
          option.selected = true
          button.classList.add("is-active")
        } else {
          option.selected = false
          button.classList.remove("is-active")
        }
      })
      control.appendChild(button)
    })
  })
  */
}
