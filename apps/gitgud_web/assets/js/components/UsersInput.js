import React from "react"
import {QueryRenderer, graphql} from "react-relay"

import environment from "../relay-environment"

class UsersInput extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      users: props.initialUsers,
      input: ""
    }
    this.dropdown = React.createRef()
    this.inputContainer = React.createRef()
    this.inputSubmitKeys = [13, 32, 188]
    this.handleFocus = this.handleFocus.bind(this)
    this.handleBlur = this.handleBlur.bind(this)
    this.handleInputChange = this.handleInputChange.bind(this)
    this.handleInputKeyDown = this.handleInputKeyDown.bind(this)
    this.handleRemoveItem = this.handleRemoveItem.bind(this)
  }

  render() {
    return (
      <div className="users-input dropdown" ref={this.dropdown}>
        <div className="dropdown-trigger">
          <div className="input field is-grouped" ref={this.inputContainer} onFocus={this.handleFocus} onBlur={this.handleBlur}>
            {this.state.users.map((user, i) =>
              <div className="control" key={i}>
                <div className="tags has-addons">
                  <a className="tag">{user}</a>
                  <a className="tag is-delete" onClick={this.handleRemoveItem(i)}></a>
                </div>
              </div>
            )}
            <div className="control is-expanded">
              <input type="text" className="input is-static" value={this.state.input} onChange={this.handleInputChange} onKeyDown={this.handleInputKeyDown} />
            </div>
            <input type="hidden" id={this.props.id} name={this.props.name} value={this.state.users.join(",")} />
          </div>
        </div>
        <div className="dropdown-menu">
          <div className="dropdown-content">
          </div>
        </div>
      </div>
    )
  }

  handleFocus() {
    this.inputContainer.current.classList.add("is-focused")
  }

  handleBlur() {
    this.inputContainer.current.classList.remove("is-focused")
  }

  handleInputChange(event) {
    const input = event.target.value
    if(input.length)
      this.dropdown.current.classList.add("is-active")
    else
      this.dropdown.current.classList.remove("is-active")
    this.setState({input: input})
  }

  handleInputKeyDown(event) {
    if(this.inputSubmitKeys.includes(event.keyCode)) {
      if(this.state.input.length) {
        const {value} = event.target
        this.dropdown.current.classList.remove("is-active")
        this.setState(state => ({
          users: [...state.users, value],
          input: ""
        }))
      }
      event.preventDefault()
    } else if(event.keyCode == 8 && this.state.users.length && !this.state.input.length) {
      this.setState(state => ({
        users: state.users.slice(0, state.users.length - 1)
      }))
    }
  }

  handleRemoveItem(index) {
    return () => {
      this.setState(state => ({
        users: state.users.filter((item, i) => i !== index)
      }))
    }
  }
}

export default UsersInput

