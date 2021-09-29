import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

import Hooks from "./live-hooks"

const csrfToken = document.querySelector("meta[name=csrf-token]").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

export default liveSocket

