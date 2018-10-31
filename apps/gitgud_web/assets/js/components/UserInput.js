import React from "react"
import {QueryRenderer, graphql} from "react-relay"

import environment from "../relay-environment"

class UserInput extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      user: "",
      input: ""
    }
    this.dropdown = React.createRef()
    this.inputContainer = React.createRef()
    this.submitButton = React.createRef()
    this.renderDropdown = this.renderDropdown.bind(this)
    this.handleSetUser = this.handleSetUser.bind(this);
    this.handleFocus = this.handleFocus.bind(this)
    this.handleBlur = this.handleBlur.bind(this)
    this.handleInputChange = this.handleInputChange.bind(this)
    this.handleInputKeyDown = this.handleInputKeyDown.bind(this)
  }

  render() {
    return (
      <div className="users-input dropdown" ref={this.dropdown}>
        <div className="dropdown-trigger">
          <div className="field is-grouped">
            <div className="control">
              <div className="input field is-grouped" style={{width: "230px"}} ref={this.inputContainer} onFocus={this.handleFocus} onBlur={this.handleBlur}>
                {this.state.user &&
                  <div className="control">
                    <a className="tag">{this.state.user.username}</a>
                    <input type="hidden" id={this.props.id} name={this.props.name} value={this.state.user.id} />
                  </div>
                }
                <div className="control is-expanded">
                  <input type="text" className="input is-static" value={this.state.input} onChange={this.handleInputChange} onKeyDown={this.handleInputKeyDown} />
                </div>
              </div>
            </div>
            <div className="control">
              <button type="submit" className="button is-link" ref={this.submitButton} disabled>Add</button>
            </div>
          </div>
        </div>
        <div className="dropdown-menu">
          {this.state.input.length && this.renderDropdown()}
        </div>
      </div>
    )
  }

  renderDropdown() {
    return (
      <div className="dropdown-content">
        <QueryRenderer
          environment={environment}
          query={graphql`
            query UserInputQuery($input: String!) {
              userSearch(input: $input, first:10) {
                edges {
                  node {
                    id
                    username
                    name
                  }
                }
              }
            }
          `}
          variables={{
            input: this.state.input
          }}
          render={({error, props}) => {
            if(error) {
              return <div>{error.message}</div>
            } else if(props) {
              return (
                <div>
                  {props.userSearch.edges.map((edge, i) =>
                    <a key={i} className="dropdown-item" onClick={this.handleSetUser(edge.node)}>{edge.node.username} <span className="has-text-grey">{edge.node.name}</span></a>
                  )}
                </div>
              )
            }
            return <div></div>
          }}
        />
      </div>
    )
  }

  handleSetUser(user) {
    return () => {
      this.dropdown.current.classList.remove("is-active")
      this.submitButton.current.disabled = false
      this.setState(state => ({
        user: user,
        input: ""
      }))
    }
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
    if(event.keyCode == 13) event.preventDefault()
    if(this.state.user) {
      if(event.keyCode == 8) {
        this.submitButton.current.disabled = true
        this.setState(state => ({
          user: ""
        }))
      } else {
        event.preventDefault()
      }
    }
  }
}

export default UserInput
