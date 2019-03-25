import {Socket} from "phoenix"

import {token} from "./auth"

let socket = new Socket("/socket", {params: (() => token ? {token: token} : {})()})

export default socket
