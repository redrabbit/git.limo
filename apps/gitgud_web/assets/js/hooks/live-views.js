import topbar from "topbar"

import liveSocket from "../live-socket"

export default () => {
  const liveViews = document.querySelectorAll("[data-phx-session]:not([data-phx-connect-later])")
  if(liveViews.length) {
    topbar.config({
      barThickness: 1.5,
      barColors: {
        0: "#2ec2a7",
        1: "#f3d270"
      },
      shadowColor: "rgba(0, 0, 0, .3)"
    })

    window.addEventListener("phx:page-loading-start", info => topbar.show())
    window.addEventListener("phx:page-loading-stop", info => topbar.hide())

    liveSocket.connect()
  }
}