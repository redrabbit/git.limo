import React from "react"
import {fetchQuery, graphql} from "react-relay"

import environment from "../relay-environment"

class SearchDropDown extends React.Component {

}

class Search extends React.Component {
  constructor(props) {
    super(props)
    this.dropdown = React.createRef()
    this.inputContainer = React.createRef()
    this.handleInputChange = this.handleInputChange.bind(this)
    this.renderSearchResult = this.renderSearchResult.bind(this)
    this.state = {input: "", results: []}
  }

  componentDidUpdate(prevProps, prevState) {
    if(this.state.input.length > 0 && this.state.input != prevState.input) {
      const query = graphql`
        query SearchQuery($input: String!) {
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
        .then(response => {
          this.setState({results: response.search.edges.map(edge => edge.node)})
        })
    }
  }

  render() {
    return (
      <div className="dropdown" ref={this.dropdown}>
        <div className="control has-icons-left">
          <input type="text" className="input" ref={this.inputContainer} onChange={this.handleInputChange} placeholder="Search ..." />
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
    return (
      <div className="dropdown-content">
        {this.state.results.map(this.renderSearchResult)}
      </div>
    )
  }

  renderSearchResult(edge) {
    switch(edge.__typename) {
      case "User":
        return (
          <a key={edge.id} href={edge.url} className="dropdown-item">
            <span className="tag user is-white">
              <img className="avatar is-small" src={edge.avatarUrl} width={24} />{edge.login}
            </span>
          </a>
        )
      case "Repo":
        return (
          <a key={edge.id} href={edge.url} className="dropdown-item">
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

  handleInputChange(event) {
    const input = event.target.value
    if(input.length)
      this.dropdown.current.classList.add("is-active")
    else
      this.dropdown.current.classList.remove("is-active")
    this.setState({input: input})
  }

}

export default Search
