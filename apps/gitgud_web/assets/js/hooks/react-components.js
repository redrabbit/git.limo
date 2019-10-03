import React from "react"
import ReactDOM from "react-dom"

import {camelCase, upperFirst} from "lodash"

import * as factory from "../components"

export default () => {
  document.querySelectorAll("[data-react-class]").forEach(e => {
    const targetId = document.getElementById(e.dataset.reactTargetId)
    const targetDiv = targetId ? targetId : e
    const reactProps = e.dataset.reactProps ? atob(e.dataset.reactProps) : "{}"
    const reactElement = React.createElement(factory[upperFirst(camelCase(e.dataset.reactClass))], JSON.parse(reactProps))
    ReactDOM.render(reactElement, targetDiv)
  })
}
