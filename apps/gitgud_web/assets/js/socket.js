import {Socket} from "phoenix"

import {token} from "./auth"

let socket = new Socket("/socket", {params: (() => token ? {token: token} : {})()})

/*
let channel = socket.channel("topic:subtopic", {})
channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })
*/

export default socket
