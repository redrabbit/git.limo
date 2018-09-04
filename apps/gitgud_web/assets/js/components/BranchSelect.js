import React from "react"
import {QueryRenderer, graphql} from "react-relay"
import {DropdownButton, MenuItem} from 'react-bootstrap';

import environment from "../relay"

class BranchSelect extends React.Component {
  constructor(props) {
    super(props)
    this.handleSelect = this.handleSelect.bind(this)
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
          repoID: "UmVwbzox"
        }}
        render={({error, props}) => {
          if(error) {
            return <div>{error.message}</div>
          } else if(props) {
            return (
              <DropdownButton id="branch-select" title={this.props.shorthand}>
                {props.node.refs.map(ref =>
                  <MenuItem key={ref.object.oid} eventKey={ref.url} onSelect={this.handleSelect} active={this.props.oid == ref.object.oid}>
                    {ref.shorthand}
                  </MenuItem>
                )}
              </DropdownButton>
            )
          }
          return <div></div>
        }}
      />
    )
  }

  handleSelect(url) {
    window.location.href = url
  }
}

export default BranchSelect
