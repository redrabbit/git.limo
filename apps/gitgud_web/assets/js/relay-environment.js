import {Environment, Observable, Network, Store, RecordSource} from "relay-runtime"

import {create} from "@absinthe/socket"
import {createSubscriber} from "@absinthe/socket-relay"

import socket from "./socket"

const absintheSocket = create(socket)
const legacySubscribe = createSubscriber(absintheSocket)

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

function subscribe(request, variables, cacheConfig) {
  return Observable.create(sink => {
    legacySubscribe(request, variables, cacheConfig, {
      onNext: sink.next,
      onError: sink.error,
      onCompleted: sink.complete
    })
  })
}

export default new Environment({
  network: Network.create(fetchQuery, subscribe),
  store: new Store(new RecordSource())
})
