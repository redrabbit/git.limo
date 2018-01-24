import "phoenix_html"

import React from "react"
import ReactDOM from "react-dom"

const Hello = function(name) {
  return (
    <div>Hello, {name}</div>
  )
}

ReactDOM.render(Hello("Will"), document.getElementById("app"));
