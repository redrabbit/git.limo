export default () => {
  document.querySelectorAll("article.message").forEach(flash => {
    let deleteButton = flash.querySelector("button.delete");
    if(deleteButton) {
      deleteButton.addEventListener("click", event => {
        flash.remove()
      })
    }
  })
}
