import liveSocket from "../live-socket"

export default () => {
  const liveViews = document.querySelectorAll("[data-phx-view]:not([data-phx-connect-later])")
  if(liveViews.length) {
    liveSocket.connect()
  }
}