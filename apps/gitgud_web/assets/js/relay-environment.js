import {Environment, Network, Store, RecordSource} from "relay-runtime"
import * as AbsintheSocket from "@absinthe/socket"
import {createFetcher, createSubscriber} from "@absinthe/socket-relay/compat/cjs"

import socket from "./socket"

const transport = AbsintheSocket.create(socket)

export default new Environment({
  network: Network.create(
    createFetcher(transport),
    createSubscriber(transport)
  ),
  store: new Store(new RecordSource())
})
