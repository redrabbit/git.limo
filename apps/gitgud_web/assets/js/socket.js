import {Socket} from "phoenix"

const token = document.querySelector("meta[name='token']")
let socket = new Socket("/socket", {params: token ? {token} : {}})

export default socket
