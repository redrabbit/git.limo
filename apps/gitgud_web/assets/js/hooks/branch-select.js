import liveSocket from "../live-socket"

function connectLiveSocket(e) {
  e.preventDefault()
  liveSocket.connect()
}

export default () => {
  const branchSelect = document.getElementById("branch-select")
  if(branchSelect) {
    const branchSelectButton = branchSelect.querySelector(".dropdown-trigger")
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        const {classList} = mutation.target
        if(classList.contains("phx-connected")) {
          delete branchSelect.dataset.phxConnectLater
          observer.disconnect()
        } else if(classList.contains("phx-disconnected")) {
          branchSelectButton.removeEventListener("click", connectLiveSocket)
        }
      })
    })

    branchSelectButton.addEventListener("click", connectLiveSocket)
    observer.observe(branchSelect, {attributes : true, attributeFilter: ["class"]})
  }
}
