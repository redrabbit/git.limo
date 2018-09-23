import {camelCase} from "lodash"

import React from "react"
import ReactDOM from "react-dom"

import * as factory from "./components"

export default () => {
  const elements = document.querySelectorAll("[data-react-class]")
  Array.prototype.forEach.call(elements, e => {
    const targetId = document.getElementById(e.dataset.reactTargetId)
    const targetDiv = targetId ? targetId : e
    const reactProps = e.dataset.reactProps ? e.dataset.reactProps : "{}"
    const reactElement = React.createElement(factory[e.dataset.reactClass], JSON.parse(reactProps))
    ReactDOM.render(reactElement, targetDiv)
  })
}
