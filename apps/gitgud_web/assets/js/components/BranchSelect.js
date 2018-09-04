import React from "react"
import {QueryRenderer, createFragmentContainer, graphql} from "react-relay"

import environment from "../relay"

class BranchSelect extends React.Component {
  constructor(props) {
    super(props)
    this.handleChange = this.handleChange.bind(this)
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
              <select onChange={this.handleChange} defaultValue={this.props.oid}>
                {props.node.refs.map(ref => <option key={ref.object.oid} value={ref.object.oid}>{ref.shorthand}</option>)}
              </select>
            )
          }
          return <div></div>
        }}
      />
    )
  }

  handleChange(e) {
    console.log(e.target.options[e.target.selectedIndex].text)
  }
}

export default BranchSelect
