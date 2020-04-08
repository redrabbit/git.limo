import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery, graphql} from "react-relay";

import environment from "../relay-environment"

class TreeTable {
  static fetchTreeEntriesWithCommit(repoId, commitOid, treePath) {
    const query = graphql`
      query TreeTableTreeEntriesWithLastCommitQuery($repoId: ID!, $commitOid: GitObjectID!, $treePath: String!) {
        node(id: $repoId) {
          ... on Repo {
            object(oid: $commitOid) {
              target {
                ... on GitCommit {
                  treeEntriesWithLastCommit(first: 50, path: $treePath) {
                    edges {
                      node {
                        treeEntry {
                          oid
                        }
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
          }
        }
      }
    `

    const variables = {
      repoId: repoId,
      commitOid: commitOid,
      treePath: treePath
    }

    return fetchQuery(environment, query, variables)
  }
}

export default TreeTable
