export default () => {
  document.querySelectorAll("article.message").forEach(flash => {
    flash.querySelector("button.delete").addEventListener("click", event => {
      flash.remove()
    })
  })
}
