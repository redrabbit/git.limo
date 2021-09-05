import liveSocket from "../live-socket"

function connectLiveSocket() {
  liveSocket.connect()
}

export default () => {
  const globalSearch = document.getElementById("global-search")
  if(globalSearch) {
    const globalSearchInput = globalSearch.querySelector("input")
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        const {classList} = mutation.target
        if(classList.contains("phx-connected")) {
          delete globalSearch.dataset.phxConnectLater
          observer.disconnect()
        } else if(classList.contains("phx-disconnected")) {
          globalSearchInput.removeEventListener("input", connectLiveSocket)
        }
      })
    })

    globalSearchInput.addEventListener("input", connectLiveSocket)
    observer.observe(globalSearch, {attributes : true, attributeFilter: ["class"]})
  }
}