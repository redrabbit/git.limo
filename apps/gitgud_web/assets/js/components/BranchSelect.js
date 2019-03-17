import React from "react"
import {QueryRenderer, graphql} from "react-relay"

import environment from "../relay-environment"

class BranchSelect extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      toggled: false,
      filter: "",
      type: "BRANCH"
    }
    this.dropdown = React.createRef()
    this.renderDropdown = this.renderDropdown.bind(this)
    this.handleToggle = this.handleToggle.bind(this)
    this.handleSearch = this.handleSearch.bind(this)
  }

  render() {
    return (
      <div className="dropdown" ref={this.dropdown}>
        <div className="dropdown-trigger">
          <button className="button" aria-haspopup="true" aria-controls="dropdown-menu" onClick={this.handleToggle}>
            <span>{this.props.type.charAt(0).toUpperCase() + this.props.type.slice(1)}: <span className="has-text-weight-semibold">{this.props.name}</span></span>
            <span className="icon is-small">
              <i className="fa fa-angle-down" aria-hidden="true"></i>
            </span>
          </button>
        </div>
        <div className="dropdown-menu">
          {this.state.toggled && this.renderDropdown()}
        </div>
      </div>
    )
  }

  renderDropdown() {
    return (
      <QueryRenderer
        environment={environment}
        query={graphql`
          query BranchSelectQuery($repoID: ID!) {
            node(id: $repoID) {
              ... on Repo {
                refs(first: 100) {
                  edges {
                    node {
                      oid
                      name
                      type
                      url
                    }
                  }
                }
              }
            }
          }
        `}
        variables={{
          repoID: this.props.repo
        }}
        render={({error, props}) => {
          if(error) {
            return <div>{error.message}</div>
          } else if(props) {
            let edge = props.node.refs.edges.find(edge => edge.node.oid == this.props.oid)
            return (
              <nav className="panel">
                <div className="panel-heading">
                  <p className="control has-icons-left">
                    <input className="input is-small" value={this.state.filter} type="text" placeholder="Filter ..." onChange={this.handleSearch} />
                    <span className="icon is-small is-left">
                      <i className="fa fa-filter" aria-hidden="true"></i>
                    </span>
                  </p>
                </div>
                <p className="panel-tabs">
                  <a className={this.state.type == "BRANCH" ? "is-active" : ""} onClick={() => this.setState({type: "BRANCH"})}>Branches</a>
                  <a className={this.state.type == "TAG" ? "is-active" : ""} onClick={() => this.setState({type: "TAG"})}>Tags</a>
                </p>
                {props.node.refs.edges.filter(edge =>
                  edge.node.type == this.state.type
                ).filter(edge =>
                  edge.node.name.includes(this.state.filter)
                ).map(edge =>
                  <a key={edge.node.oid} href={edge.node.url} className={"panel-block" + (this.props.oid == edge.node.oid ? " is-active" : "")}>{edge.node.name}</a>
                )}
                <div className="panel-block">
                  <a className="button is-small is-light is-fullwidth">reset all filters</a>
                </div>
              </nav>
            )
          }
          return <div></div>
        }}
      />
    )
  }

  handleToggle() {
    const toggled = this.state.toggled
    if(!toggled)
      this.dropdown.current.classList.add("is-active")
    else
      this.dropdown.current.classList.remove("is-active")
    this.setState({toggled: !toggled})
  }

  handleSearch(event) {
    this.setState({filter: event.target.value})
  }
}

export default BranchSelect
