import "phoenix_html"

import React from "react"
import ReactDOM from "react-dom"

class BranchSelect extends React.Component {
  constructor(props) {
    super(props)
    this.change = this.change.bind(this)
  }

  render() {
    return (
      <select onChange={this.change} defaultValue={this.props.oid}>
        {this.props.branches.map((branch, i) =>
          <option key={i} value={branch.oid}>{branch.shorthand}</option>
        )}
      </select>
    )
  }

  change(event) {
    let oid = event.target.options[event.target.selectedIndex].value
    let branch = this.props.branches.find(branch => branch.oid == oid)
    window.location = branch.path
  }
}

document.addEventListener("DOMContentLoaded", e => {
  const elements = document.querySelectorAll("[data-react-class]")
  Array.prototype.forEach.call(elements, e => {
    const targetId = document.getElementById(e.dataset.reactTargetId)
    const targetDiv = targetId ? targetId : e
    const reactProps = e.dataset.reactProps ? e.dataset.reactProps : "{}"
    const reactElement = React.createElement(eval(e.dataset.reactClass), JSON.parse(reactProps))
    ReactDOM.render(reactElement, targetDiv)
  })
})
