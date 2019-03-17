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
    this.submitButton = React.createRef()
    this.renderDropdown = this.renderDropdown.bind(this)
    this.handleTagUser = this.handleTagUser.bind(this);
    this.handleReset = this.handleReset.bind(this);
    this.handleFocus = this.handleFocus.bind(this)
    this.handleBlur = this.handleBlur.bind(this)
    this.handleInputChange = this.handleInputChange.bind(this)
    this.handleInputKeyDown = this.handleInputKeyDown.bind(this)
  }

  render() {
    return (
      <div className="dropdown" ref={this.dropdown}>
        <div className="dropdown-trigger">
          <div className="field is-grouped">
            <div className="control is-expanded">
              <div className="input field is-grouped" onFocus={this.handleFocus} onBlur={this.handleBlur}>
                {this.state.user &&
                  <div className="control">
                    <a className="tag is-medium is-white" onClick={this.handleReset}>{this.state.user.login}</a>
                    <input type="hidden" id={this.props.id} name={this.props.name} value={this.state.user.id} />
                  </div>
                }
                <div className="control is-expanded">
                  <input type="text" className="input is-static" value={this.state.input} onChange={this.handleInputChange} onKeyDown={this.handleInputKeyDown} />
                </div>
              </div>
            </div>
            <div className="control">
              <button type="submit" className="button is-success" ref={this.submitButton} disabled>Add</button>
            </div>
          </div>
        </div>
        <div className="dropdown-menu">
          {this.state.input.length > 0 && this.renderDropdown()}
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
              search(user: $input, first:10) {
                edges {
                  node {
                    ... on User {
                      id
                      login
                      name
                    }
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
                  {props.search.edges.filter(edge => !this.props.reject.includes(edge.node.id)).map((edge, i) =>
                    <a key={i} className="dropdown-item" onClick={this.handleTagUser(edge.node)}>{edge.node.login} <span className="has-text-grey">{edge.node.name}</span></a>
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

  handleTagUser(user) {
    return () => {
      this.dropdown.current.classList.remove("is-active")
      this.submitButton.current.disabled = false
      this.setState({user: user, input: ""})
    }
  }

  handleReset() {
    this.submitButton.current.disabled = true
    this.setState({user: ""})
  }

  handleFocus(event) {
    event.target.classList.add("is-focused")
  }

  handleBlur(event) {
    event.target.classList.remove("is-focused")
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
        this.setState({user: ""})
      } else {
        event.preventDefault()
      }
    }
  }
}

export default UserInput
