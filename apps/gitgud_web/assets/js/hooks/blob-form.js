export default () => {
  const form = document.getElementById("blob-form")
  if(form) {
    let nameInput = form.querySelector("input[name=\"commit[name]\"]")
    const defaultName = nameInput.value
    let methodInput = form.querySelector("input[name=\"_method\"]")
    let messageInput = form.querySelector("input[name=\"commit[message]\"]")
    nameInput.addEventListener("input", event => {
      const fileName = event.target.value
      if(methodInput && methodInput.value == "put") {
        if(fileName == defaultName) {
          messageInput.placeholder = `Update ${defaultName}`
        } else {
          messageInput.placeholder = `Rename ${defaultName} to ${fileName}`
        }
      } else {
        messageInput.placeholder = `Create ${fileName}`
      }
    })
  }
}
