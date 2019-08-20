import React from "react"
import ReactDOM from "react-dom"

import moment from "moment"

import {fetchQuery, graphql} from "react-relay";

import environment from "../relay-environment"

import CommitSignature from "./CommitSignature"

class BlobTableHeader extends React.Component {
  render() {
    const {commit} = this.props
    const timestamp = moment.utc(commit.timestamp)
    const {author, committer} = commit
    const messageTitle = commit.message.split("\n", 1)[0].trim()
    return (
      <header className="card-header">
        <div className="card-header-title">
          <CommitSignature author={author} committer={committer} />
          &nbsp;<a href={commit.url} className="has-text-grey">{messageTitle}</a>
        </div>
        <div className="card-header-icon">
          <time className="tooltip has-text-grey" date-time={timestamp.format()}  data-tooltip={timestamp.format()}>{timestamp.fromNow()}</time>
        </div>
      </header>
    )
  }

  static fetchTreeEntryWithCommit(repoId, commitOid, blobPath) {
    const query = graphql`
      query BlobTableHeaderTreeEntryWithLastCommitQuery($repoId: ID!, $commitOid: GitObjectID!, $blobPath: String!) {
        node(id: $repoId) {
          ... on Repo {
            object(oid: $commitOid) {
              ... on GitCommit {
                treeEntryWithLastCommit(path: $blobPath) {
                  commit {
                    message
                    timestamp
                    committer {
                      ... on User {
                        login
                        avatarUrl
                        url
                      }
                      ... on UnknownUser {
                        name
                        email
                      }
                    }
                    author {
                      ... on User {
                        login
                        avatarUrl
                        url
                      }
                      ... on UnknownUser {
                        name
                        email
                      }
                    }
                    url
                  }
                }
              }
            }
          }
        }
      }
    `

    const variables = {
      repoId: repoId,
      commitOid: commitOid,
      blobPath: blobPath
    }

    return fetchQuery(environment, query, variables)
  }
}

export default BlobTableHeader
