import "phoenix_html"

import {camelCase} from "lodash"

import React from "react"
import ReactDOM from "react-dom"

import * as factory from "./components"

document.addEventListener("DOMContentLoaded", e => {
  const elements = document.querySelectorAll("[data-react-class]")
  Array.prototype.forEach.call(elements, e => {
    const targetId = document.getElementById(e.dataset.reactTargetId)
    const targetDiv = targetId ? targetId : e
    const reactProps = e.dataset.reactProps ? e.dataset.reactProps : "{}"
    const reactElement = React.createElement(factory[e.dataset.reactClass], JSON.parse(reactProps, (key, val) => {
      if(val && typeof val === 'object') Object.keys(val).reduce((ccObj, field) => ({...ccObj, [camelCase(field)]: val[field]}), {})
      return val;
    }))
    ReactDOM.render(reactElement, targetDiv)
  })
})
