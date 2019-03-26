import React from "react"
import {QueryRenderer, graphql} from "react-relay"

import environment from "../relay-environment"

class Search extends React.Component {
  constructor(props) {
    super(props)
    this.dropdown = React.createRef()
    this.inputContainer = React.createRef()
    this.handleInputChange = this.handleInputChange.bind(this)
    this.renderSearchResult = this.renderSearchResult.bind(this)
    this.state = {input: ""}
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
        <QueryRenderer
          environment={environment}
          query={graphql`
            query SearchQuery($input: String!) {
              search(all: $input, first:10) {
                edges {
                  node {
                    __typename
                    ... on User {
                      id
                      login
                      name
                      url
                    }
                    ... on Repo {
                      id
                      name
                      owner {
                        login
                      }
                      url
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
                  {props.search.edges.map(this.renderSearchResult)}
                </div>
              )
            }
            return <div></div>
          }}
        />
      </div>
    )
  }

  renderSearchResult(edge) {
    switch(edge.node.__typename) {
      case "User":
        return (
          <a key={edge.node.id} href={edge.node.url} className="dropdown-item">
            <span className="icon">
              <i className="fa fa-user"></i>
            </span>
            {edge.node.login} <span className="has-text-grey">{edge.node.name}</span>
          </a>
        )
      case "Repo":
        return (
          <a key={edge.node.id} href={edge.node.url} className="dropdown-item">
            <span className="icon">
              <i className="fa fa-archive"></i>
            </span>
            <span>{edge.node.owner.login} / {edge.node.name}</span>
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
