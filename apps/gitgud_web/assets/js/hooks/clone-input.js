export default () => {
  document.querySelectorAll(".clone-repo").forEach(field => {
    let httpCloneButton = field.querySelector(".http-clone-button")
    let httpCloneInput = field.querySelector(".http-clone input")
    let sshCloneButton = field.querySelector(".ssh-clone-button")
    let sshCloneInput = field.querySelector(".ssh-clone input")
    let clipboardButton = field.querySelector(".clipboard-button")

    httpCloneButton.addEventListener("click", event => {
      httpCloneButton.classList.add("is-active")
      httpCloneInput.parentNode.classList.remove("is-hidden")
      sshCloneButton.classList.remove("is-active")
      sshCloneInput.parentNode.classList.add("is-hidden")
    })

    sshCloneButton.addEventListener("click", event => {
      sshCloneButton.classList.add("is-active")
      sshCloneInput.parentNode.classList.remove("is-hidden")
      httpCloneButton.classList.remove("is-active")
      httpCloneInput.parentNode.classList.add("is-hidden")
    })

    clipboardButton.addEventListener("click", event => {
      let input = field.querySelector(".control:not(.is-hidden) input")
      input.focus()
      input.select()
      document.execCommand("copy")
      input.selectionEnd = input.selectionStart
      clipboardButton.dataset.tooltip = "Copied"
    })

    clipboardButton.addEventListener("mouseenter", event => {
      let input = field.querySelector(".control:not(.is-hidden) input")
      input.focus()
      input.selectionEnd = input.selectionStart
      clipboardButton.classList.add("is-link")
      clipboardButton.classList.add("is-outlined")
    })

    clipboardButton.addEventListener("mouseleave", event => {
      let input = field.querySelector(".control:not(.is-hidden) input")
      input.blur()
      clipboardButton.classList.remove("is-link")
      clipboardButton.classList.remove("is-outlined")
      clipboardButton.dataset.tooltip = "Copy to clipboard"
    })
  })
}
