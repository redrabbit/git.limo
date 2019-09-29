import React from "react"
import {QueryRenderer, graphql} from "react-relay"

import environment from "../relay-environment"

import IssueLabel from "./IssueLabel"

class IssueLabelSelect extends React.Component {
  constructor(props) {
    super(props)
    this.renderMenuLabel = this.renderMenuLabel.bind(this)
    this.handleEdit = this.handleEdit.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.handleLabelToggle = this.handleLabelToggle.bind(this)
    this.isActive = this.isActive.bind(this)
    this.state = {
      edit: false,
      push: [],
      pull: []
    }
  }

  isActive(id) {
    const {selectedLabels} = this.props
    const {push, pull} = this.state
    return push.includes(id) || (selectedLabels.includes(id) && !pull.includes(id))
  }

  render() {
    const {labels, selectedLabels} = this.props
    const {edit} = this.state
    if(edit) {
      return (
        <div className="issue-label-select">
          {this.renderMenuLabel()}
          <div className="field">
            <div className="control">
              {labels.map((label, i) =>
                <IssueLabel key={i} {...label} active={this.isActive(label.id)} edit={edit} onToggle={() => this.handleLabelToggle(label.id)}/>
              )}
            </div>
          </div>
        </div>
      )
    } else {
      const activeLabels = labels.filter(label => selectedLabels.includes(label.id))
      return (
        <div className="issue-label-select">
          {this.renderMenuLabel()}
          <div className="field">
            <div className="control">
              {activeLabels.length > 0 ? activeLabels.map((label, i) => <IssueLabel key={i} {...label} active={true} />) : <p className="is-size-7">None yet</p>}
            </div>
          </div>
        </div>
      )
    }
  }

  renderMenuLabel() {
    const {editable} = this.props
    const {edit} = this.state
    if(edit) {
      return (
        <div className="menu-label">
          Labels
          <div className="buttons is-pulled-right">
            <button className="button is-link is-small is-inverted" onClick={this.handleSubmit} disabled={this.state.push.length == 0 && this.state.pull.length == 0}>
              <span className="icon">
                <i className="fa fa-check"></i>
              </span>
            </button>
            <button className="button is-white is-small has-text-grey-light" onClick={this.handleCancel}>
              <span className="icon">
                <i className="fa fa-times"></i>
              </span>
            </button>
          </div>
        </div>
      )
    } else if(editable) {
      return (
        <div className="menu-label">
          Labels
          <button className="button is-white is-small is-pulled-right has-text-grey-light" onClick={this.handleEdit}>
            <span className="icon">
              <i className="fa fa-cog"></i>
            </span>
          </button>
        </div>
      )
    } else {
      return <p className="menu-label">Labels</p>
    }
  }

  handleEdit() {
    this.setState({edit: true})
  }

  handleSubmit() {
    const {push, pull} = this.state
    this.setState({edit: false, push: [], pull: []})
    this.props.onSubmit(push, pull)
  }

  handleCancel() {
    this.setState({edit: false, push: [], pull: []})
  }

  handleLabelToggle(id) {
    const {selectedLabels} = this.props
    const {push, pull} = this.state
    if(push.includes(id)) {
      this.setState({push: this.state.push.filter(pushId => pushId != id)})
    } else if(pull.includes(id)) {
      this.setState({pull: this.state.pull.filter(pullId => pullId != id)})
    } else if(selectedLabels.includes(id)){
      this.setState({pull: [...this.state.pull, id]})
    } else {
      this.setState({push: [...this.state.push, id]})
    }
  }
}

export default IssueLabelSelect
