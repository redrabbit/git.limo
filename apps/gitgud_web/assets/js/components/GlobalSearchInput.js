import React from "react"
import {fetchQuery, graphql} from "react-relay"

import environment from "../relay-environment"

class GlobalSearchInput extends React.Component {
  constructor(props) {
    super(props)
    this.dropdown = React.createRef()
    this.inputContainer = React.createRef()
    this.handleInputKeyDown = this.handleInputKeyDown.bind(this)
    this.handleInputChange = this.handleInputChange.bind(this)
    this.renderSearchResult = this.renderSearchResult.bind(this)
    this.state = {input: "", results: [], activeItem: 0}
  }

  componentDidUpdate(prevProps, prevState) {
    if(this.state.input.length > 0 && this.state.input != prevState.input) {
      const query = graphql`
        query GlobalSearchInputQuery($input: String!) {
          search(all: $input, first:10) {
            edges {
              node {
                __typename
                ... on User {
                  id
                  login
                  avatarUrl
                  url
                }
                ... on Repo {
                  id
                  name
                  owner {
                    login
                    avatarUrl
                  }
                  url
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
        .then(response => this.setState({results: response.search.edges.map(edge => edge.node), activeItem: 0}))
    }
  }

  render() {
    return (
      <div className="dropdown" ref={this.dropdown}>
        <div className="control has-icons-left">
          <input type="text" className="input" ref={this.inputContainer} onKeyDown={this.handleInputKeyDown} onChange={this.handleInputChange} placeholder="Search ..." />
          <span className="icon is-small is-left">
            <i className="fa fa-search"></i>
          </span>
        </div>
        <div className="dropdown-menu">
          {this.state.input.length > 0 && this.renderDropdown()}
        </div>
      </div>
    )
  }

  renderDropdown() {
    if(this.state.results.length > 0) {
      return (
        <div className="dropdown-content">
          {this.state.results.map(this.renderSearchResult)}
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

  renderSearchResult(edge, i) {
    let classNames = ["dropdown-item"]
    if(i == this.state.activeItem)
      classNames.push("is-selected")
    switch(edge.__typename) {
      case "User":
        return (
          <a key={edge.id} href={edge.url} className={classNames.join(" ")} onMouseOver={() => this.setState({activeItem: i})}>
            <span className="tag user is-white">
              <img className="avatar is-small" src={edge.avatarUrl} width={24} />{edge.login}
            </span>
          </a>
        )
      case "Repo":
        return (
          <a key={edge.id} href={edge.url} className={classNames.join(" ")} onMouseOver={() => this.setState({activeItem: i})}>
            <div className="tags has-addons">
              <span className="tag user is-white">
                <img className="avatar is-small" src={edge.owner.avatarUrl} width={24} />{edge.owner.login}
              </span>
              <span className="tag is-link">{edge.name}</span>
            </div>
          </a>
        )
    }
  }

  handleInputKeyDown(event) {
    if(this.state.results.length > 0) {
      switch(event.key) {
        case "Enter":
          window.location.href = this.state.results[this.state.activeItem].url
          break
        case "ArrowUp":
          this.setState(state => {
            return {activeItem: state.activeItem == 0 ? state.results.length - 1 : state.activeItem  - 1}
          })
          event.preventDefault()
          break
        case "ArrowDown":
          this.setState(state => {
            return {activeItem: state.activeItem < state.results.length - 1 ? state.activeItem  + 1 : 0}
          })
          event.preventDefault()
          break
      }
    }
  }

  handleInputChange(event) {
    const input = event.target.value
    if(input.length)
      this.dropdown.current.classList.add("is-active")
    else
      this.dropdown.current.classList.remove("is-active")
    this.setState({input: input})
  }

}

export default GlobalSearchInput
