import React from "react"
import {QueryRenderer, graphql} from "react-relay"

import environment from "../relay-environment"

class BranchSelect extends React.Component {
  constructor(props) {
    super(props)
    this.state = {
      toggled: false,
      filter: "",
      type: "branch"
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
                  shorthand
                  url
                  object {
                    oid
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
            return (
              <div className="dropdown" ref={this.dropdown}>
                <div className="dropdown-trigger">
                  <button className="button" aria-haspopup="true" aria-controls="dropdown-menu" onClick={this.handleToggle}>
                    <span>{props.node.refs.find(ref => ref.object.oid == this.props.spec.oid).shorthand}</span>
                    <span className="icon is-small">
                      <i className="fa fa-angle-down" aria-hidden="true"></i>
                    </span>
                  </button>
                </div>
                {this.state.toggled &&
                  <div className="dropdown-menu">
                    <nav className="branch-select panel">
                      <div className="panel-heading">
                        <p className="control has-icons-left">
                          <input className="input is-small" type="text" placeholder="search" onChange={this.handleSearch} />
                          <span className="icon is-small is-left">
                            <i className="fa fa-search" aria-hidden="true"></i>
                          </span>
                        </p>
                      </div>
                      <p className="panel-tabs">
                        <a className={this.state.type == "branch" ? "is-active" : ""} onClick={() => this.setState({type: "branch"})}>Branches</a>
                        <a className={this.state.type == "tag" ? "is-active" : ""} onClick={() => this.setState({type: "tag"})}>Tags</a>
                      </p>
                      {props.node.refs.filter(ref =>
                        ref.shorthand.includes(this.state.filter)
                      ).map(ref =>
                        <a key={ref.object.oid} href={ref.url} className={"panel-block" + (this.props.spec.oid == ref.object.oid ? " is-active" : "")}>{ref.shorthand}</a>
                      )}
                    </nav>
                  </div>
                }
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
