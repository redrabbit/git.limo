import React from "react"
import ReactDOM from "react-dom"

import moment from "moment"

import {fetchQuery, graphql} from "react-relay";

import environment from "../relay-environment"

class BlobTableHeader extends React.Component {
  render() {
    const {commit} = this.props
    const timestamp = moment.utc(commit.timestamp)
    const {author, committer} = commit
    return (
      <header className="card-header blob-commit">
        <div className="card-header-title">
          {committer.login ? (
            author.login && author.login !== committer.login ? (
              <div className="avatar-stack">
                <a className="has-text-black" href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={20} />{committer.login}</a>
                <a className="has-text-black" href={author.url}><img className="avatar is-small" src={author.avatarUrl} width={20} />{author.login}</a>
              </div>
            ) : (
              <a className="has-text-black" href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={20} />{committer.login}</a>
            )
          ) : (
            <span className="has-text-black">{committer.name}</span>
          )} &nbsp;<a href={commit.url} className="has-text-grey-light">{commit.message.split("\n", 1)[0].trim()}</a>
        </div>
        <div className="card-header-icon">
          <time className="tooltip has-text-grey-light" date-time={timestamp.format()}  data-tooltip={timestamp.format()}>{timestamp.fromNow()}</time>
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
