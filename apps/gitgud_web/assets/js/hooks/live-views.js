import liveSocket from "../live-socket"

export default () => {
  const liveViews = document.querySelectorAll("[data-phx-view]")
  if(liveViews.length) {
    liveSocket.connect()
  }
}

