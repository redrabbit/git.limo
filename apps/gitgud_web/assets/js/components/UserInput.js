import React from "react"
import {fetchQuery, graphql} from "react-relay"

import environment from "../relay-environment"

class UserInput extends React.Component {
  constructor(props) {
    super(props)
    this.dropdown = React.createRef()
    this.renderDropdown = this.renderDropdown.bind(this)
    this.handleTagUser = this.handleTagUser.bind(this);
    this.handleReset = this.handleReset.bind(this);
    this.handleFocus = this.handleFocus.bind(this)
    this.handleBlur = this.handleBlur.bind(this)
    this.handleInputChange = this.handleInputChange.bind(this)
    this.handleInputKeyDown = this.handleInputKeyDown.bind(this)
    this.state = {input: "", users: [], user: null}
  }

  componentDidUpdate(prevProps, prevState) {
    if(this.state.input != prevState.input) {
      const query = graphql`
        query UserInputQuery($input: String!) {
          search(user: $input, first:10) {
            edges {
              node {
                ... on User {
                  id
                  login
                  avatarUrl
                }
              }
            }
          }
        }
      `
      const variables = {
        input: this.state.input
      }

      fetchQuery(environment, query, variables)
        .then(response => {
          this.setState({users: response.search.edges.map(edge => edge.node)})
        })
    }
  }

  render() {
    return (
      <div className="dropdown" ref={this.dropdown}>
        <div className="dropdown-trigger">
          <div className="input field is-grouped" onFocus={this.handleFocus} onBlur={this.handleBlur}>
            {this.state.user &&
              <div className="control">
                <a className="tag is-medium is-white" onClick={this.handleReset}>{this.state.user.login}</a>
              </div>
            }
            <div className="control is-expanded">
              <input type="text" className="input is-static" value={this.state.input} onChange={this.handleInputChange} onKeyDown={this.handleInputKeyDown} />
              <input type="hidden" id={this.props.id} name={this.props.name} value={this.state.user ? this.state.user.login : this.state.input} />
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
    const filteredUsers = this.state.users.filter(user => !this.props.reject.includes(user.id))
    if(filteredUsers.length > 0) {
      return (
        <div className="dropdown-content">
          {filteredUsers.map((user, i) =>
            <a key={i} className="dropdown-item" onClick={this.handleTagUser(user)}>
              <span className="tag user is-white">
                <img className="avatar is-small" src={user.avatarUrl} width={24} />{user.login}
              </span>
            </a>
          )}
        </div>
      )
    } else {
      return (
        <div className="dropdown-content">
          <div className="dropdown-item">
            Nothing to see here.
          </div>
        </div>
      )
    }
  }

  handleTagUser(user) {
    return () => {
      this.dropdown.current.classList.remove("is-active")
      this.setState({user: user, input: ""})
    }
  }

  handleReset() {
    this.setState({user: null})
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
        this.setState({user: null})
      } else {
        event.preventDefault()
      }
    }
  }
}

export default UserInput
