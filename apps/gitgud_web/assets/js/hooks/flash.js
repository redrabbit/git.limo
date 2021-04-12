export default () => {
  const flash = document.getElementById("flash")
  if(flash) {
    flash.querySelectorAll("article.message").forEach(message => {
      let deleteButton = message.querySelector("button.delete");
      if(deleteButton) {
        deleteButton.addEventListener("click", event => {
          message.remove()
        })
      }
    })
  }
}
