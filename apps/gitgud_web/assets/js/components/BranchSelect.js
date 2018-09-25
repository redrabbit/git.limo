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
    this.handleToggle = this.handleToggle.bind(this)
    this.handleSearch = this.handleSearch.bind(this)
  }

  render() {
    return (
      <QueryRenderer
        environment={environment}
        query={graphql`
          query BranchSelectQuery($repoID: ID!) {
            node(id: $repoID) {
              ... on Repo {
                refs {
                  oid
                  shorthand
                  type
                  url
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
            let ref = props.node.refs.find(ref => ref.oid == this.props.oid)
            return (
              <div className="branch-select dropdown" ref={this.dropdown}>
                <div className="dropdown-trigger">
                  <button className="button" aria-haspopup="true" aria-controls="dropdown-menu" onClick={this.handleToggle}>
                    <span>{ref.type.charAt(0) + ref.type.toLowerCase().slice(1)}: <strong>{ref.shorthand}</strong></span>
                    <span className="icon is-small">
                      <i className="fa fa-angle-down" aria-hidden="true"></i>
                    </span>
                  </button>
                </div>
                <div className="dropdown-menu">
                  <nav className="panel">
                    <div className="panel-heading">
                      <p className="control has-icons-left">
                        <input className="input is-small" value={this.state.filter} type="text" placeholder="search" onChange={this.handleSearch} />
                        <span className="icon is-small is-left">
                          <i className="fa fa-search" aria-hidden="true"></i>
                        </span>
                      </p>
                    </div>
                    <p className="panel-tabs">
                      <a className={this.state.type == "BRANCH" ? "is-active" : ""} onClick={() => this.setState({type: "BRANCH"})}>Branches</a>
                      <a className={this.state.type == "TAG" ? "is-active" : ""} onClick={() => this.setState({type: "TAG"})}>Tags</a>
                    </p>
                    {props.node.refs.filter(ref =>
                      ref.type == this.state.type
                    ).filter(ref =>
                      ref.shorthand.includes(this.state.filter)
                    ).map(ref =>
                      <a key={ref.oid} href={ref.url} className={"panel-block" + (this.props.oid == ref.oid ? " is-active" : "")}>{ref.shorthand}</a>
                    )}
                  </nav>
                </div>
              </div>
            )
          }
          return <div></div>
        }}
      />
    )
  }

  handleToggle(event) {
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
