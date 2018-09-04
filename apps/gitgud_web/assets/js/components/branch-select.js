import React from "react"

export default class BranchSelect extends React.Component {
  constructor(props) {
    super(props)
  }

  render() {
    return (
      <select onChange={this.change} defaultValue={this.props.oid}>
        <option value={this.props.oid}>{this.props.shorthand}</option>
      </select>
    )
  }
}
