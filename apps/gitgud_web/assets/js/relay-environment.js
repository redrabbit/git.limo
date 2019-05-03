import {Environment, Network, Store, RecordSource} from "relay-runtime"

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
    fetchQuery
  ),
  store: new Store(new RecordSource())
})
