import {Environment, Network, Store, RecordSource} from "relay-runtime"

import {create} from "@absinthe/socket"
import {createSubscriber} from "@absinthe/socket-relay"

import socket from "./socket"

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
    createSubscriber(create(socket))
  ),
  store: new Store(new RecordSource())
})
