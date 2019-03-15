import {Socket} from "phoenix"
import {Environment, Network, Store, RecordSource} from "relay-runtime"
import * as AbsintheSocket from "@absinthe/socket"
import {createFetcher, createSubscriber} from "@absinthe/socket-relay/compat/cjs"

const token = (() => {
  let meta = document.getElementsByName("token")
  if(meta.length > 0) return meta[0].getAttribute("content")
})()

const transport = AbsintheSocket.create(new Socket("/socket", {params: (() => token ? {token: token} : {})()}))

function fetchQuery(operation, variables) {
  return fetch("/graphql", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      query: operation.text,
      variables,
    }),
  }).then(response => response.json())
}

export default new Environment({
  network: Network.create(
    fetchQuery,
    createSubscriber(transport)
  ),
  store: new Store(new RecordSource())
})
