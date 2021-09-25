import liveSocket from "../live-socket"

function connectLiveSocket(e) {
  e.currentTarget.dataset.phxConnectLater = "toggle_dropdown"
  e.preventDefault()
  liveSocket.connect()
}

export default () => {
  const branchSelect = document.getElementById("branch-select")
  if(branchSelect) {
    const branchSelectDropdown = branchSelect.querySelector(".dropdown")
    const observer = new MutationObserver((mutations) => {
      mutations.slice(-1).forEach((mutation) => {
        const {classList} = mutation.target
        if(classList.contains("phx-connected")) {
          if(branchSelect.dataset.phxConnectLater=="toggle_dropdown") {
            let hook = liveSocket.getViewByEl(branchSelect).getHook(branchSelectDropdown)
            hook.pushEventTo(branchSelectDropdown, "toggle_dropdown", {})
          }
          delete branchSelect.dataset.phxConnectLater
          observer.disconnect()
        } else if(classList.contains("phx-disconnected")) {
          branchSelect.removeEventListener("click", connectLiveSocket)
        }
      })
    })

    branchSelect.addEventListener("click", connectLiveSocket)
    observer.observe(branchSelect, {attributes : true, attributeFilter: ["class"]})
  }
}
