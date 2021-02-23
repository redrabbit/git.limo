import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery,commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"
import socket from "../socket"
import {currentUser} from "../auth"

import {Presence} from "phoenix"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

class CommitLineReview extends React.Component {
  constructor(props) {
    super(props)
    this.fetchLineReview = this.fetchLineReview.bind(this)
    this.subscriptions = []
    this.channel = null
    this.presence = null
    this.subscribePresence = this.subscribePresence.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.renderComments = this.renderComments.bind(this)
    this.renderPresences = this.renderPresences.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleFormCancel = this.handleFormCancel.bind(this)
    this.handleFormTyping = this.handleFormTyping.bind(this)
    this.handleCommentCreate = this.handleCommentCreate.bind(this)
    this.handleCommentUpdate = this.handleCommentUpdate.bind(this)
    this.handleCommentDelete = this.handleCommentDelete.bind(this)
    this.destroyComponent = this.destroyComponent.bind(this)
    this.state = {
      folded: !!props.id,
      comments: this.props.comments || [],
      presences: []
    }
  }

  componentDidMount() {
    this.fetchLineReview()
  }

  componentWillUnmount() {
    this.subscriptions.forEach(subscription => subscription.dispose())
    if(this.channel) {
      this.channel.leave()
    }
  }

  fetchLineReview() {
    const {id} = this.props
    if(id) {
      if(this.state.comments.length == 0) {
        const query = graphql`
          query CommitLineReviewQuery($id: ID!) {
            node(id: $id) {
              ... on CommitLineReview {
                comments(first: 100) {
                  edges {
                    node {
                      id
                      author {
                        login
                        avatarUrl
                        url
                      }
                      editable
                      deletable
                      body
                      bodyHtml
                      insertedAt
                    }
                  }
                }
              }
            }
          }
        `
        const variables = {
          id: id
        }

        fetchQuery(environment, query, variables)
          .then(response => {
            this.setState({
              comments: response.node.comments.edges.map(edge => edge.node)
            })
            this.subscribePresence(id)
            this.subscribeComments(id)
          })
      } else {
        this.subscribePresence(id)
        this.subscribeComments(id)
      }
    }
  }

  static fetchLineReviews(repoId, commitOid) {
    const query = graphql`
      query CommitLineReviewCommitLineReviewsQuery($repoId: ID!, $commitOid: GitObjectID!) {
        node(id: $repoId) {
          ... on Repo {
            object(oid: $commitOid) {
              ... on GitCommit {
                lineReviews(first: 100) {
                  edges {
                    node {
                      id
                      blobOid
                      hunk
                      line
                      comments(first: 100) {
                        edges {
                          node {
                            id
                            author {
                              login
                              avatarUrl
                              url
                            }
                            editable
                            deletable
                            body
                            bodyHtml
                            insertedAt
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
      }
    `

    const variables = {
      repoId: repoId,
      commitOid: commitOid,
    }

    return fetchQuery(environment, query, variables)
  }

  static subscribeNewLineReviews(repoId, commitOid, config) {
    const subscription = graphql`
      subscription CommitLineReviewCreateSubscription($repoId: ID!, $commitOid: GitObjectID!) {
        commitLineReviewCreate(repoId: $repoId, commitOid: $commitOid) {
          id
          blobOid
          hunk
          line
          comments(first: 100) {
            edges {
              node {
                id
                author {
                  login
                  avatarUrl
                  url
                }
                editable
                deletable
                body
                bodyHtml
                insertedAt
              }
            }
          }
        }
      }
    `

    const variables = {
      repoId: repoId,
      commitOid: commitOid,
    }

    return requestSubscription(environment, {...config, ...{subscription, variables}})
  }

  subscribePresence(id) {
    this.channel = socket.channel(`commit_line_review:${id}`)
    this.presence = new Presence(this.channel)
    this.presence.onSync(() => this.setState({presences: this.presence.list()}))
    return this.channel.join()
  }

  subscribeComments(id) {
    this.subscriptions.push(this.subscribeCommentCreate(id))
    this.subscriptions.push(this.subscribeCommentUpdate(id))
    this.subscriptions.push(this.subscribeCommentDelete(id))
  }

  subscribeCommentCreate(id) {
    const subscription = graphql`
      subscription CommitLineReviewCommentCreateSubscription($id: ID!) {
        commitLineReviewCommentCreate(id: $id) {
          id
          author {
            login
            avatarUrl
            url
          }
          editable
          deletable
          body
          bodyHtml
          insertedAt
        }
      }
    `

    const variables = {
      id: id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentCreate(response.commitLineReviewCommentCreate),
      onError: error => console.error(error)
    })
  }

  subscribeCommentUpdate(id) {
    const subscription = graphql`
      subscription CommitLineReviewCommentUpdateSubscription($id: ID!) {
        commitLineReviewCommentUpdate(id: $id) {
          id
          body
          bodyHtml
        }
      }
    `

    const variables = {
      id: id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentUpdate(response.commitLineReviewCommentUpdate),
      onError: error => console.error(error)
    })
  }

  subscribeCommentDelete(id) {
    const subscription = graphql`
      subscription CommitLineReviewCommentDeleteSubscription($id: ID!) {
        commitLineReviewCommentDelete(id: $id) {
          id
        }
      }
    `

    const variables = {
      id: id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentDelete(response.commitLineReviewCommentDelete),
      onError: error => console.error(error)
    })
  }

  render() {
    return (
      <td colSpan={4}>
        <div className="timeline">
          {this.renderComments()}
          {this.renderPresences()}
          {currentUser &&
            <div className="timeline-item">
              <div className="timeline-content">
                {this.renderForm()}
              </div>
            </div>
          }
        </div>
      </td>
    )
  }

  renderComments() {
    return this.state.comments.map((comment, index) =>
      <div key={index} className="timeline-item">
        <div className="timeline-content">
          <Comment repoId={this.props.repoId} comment={comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
        </div>
      </div>
    )
  }

  renderPresences() {
    const presences = this.state.presences.filter(({metas}) => metas.some(meta => meta.typing)).map(({user}) => user)
    if(presences.length > 0) {
      return (
        <div className="timeline-item">
          <div className="timeline-marker is-icon">
            <i className="fa fa-i-cursor"></i>
          </div>
          <div className="timeline-content">
            <span className="loading-ellipsis">
              {presences.map((user, i) => [
                i > 0 && (i+1 == presences.length ? " and " : ", "),
                <a key={i} href={user.url} className="has-text-black">{user.login}</a>
              ])}
              {presences.length > 1 ? " are " : " is "} typing
            </span>
          </div>
        </div>
      )
    }
  }

  renderForm() {
    if(this.state.folded) {
      return (
        <div className="comment-form">
          <form>
            <div className="field">
              <div className="control">
                <input name="comment[body]" className="input" placeholder="Leave a comment" onFocus={() => this.setState({folded: false})} />
              </div>
            </div>
          </form>
        </div>
      )
    } else {
      return <CommentForm repoId={this.props.repoId} onSubmit={this.handleFormSubmit} onTyping={this.handleFormTyping} onCancel={this.handleFormCancel} />
    }
  }

  handleFormSubmit(body) {
    const variables = {
      repoId: this.props.repoId,
      commitOid: this.props.commitOid,
      blobOid: this.props.blobOid,
      hunk: this.props.hunk,
      line: this.props.line,
      body: body
    }

    const mutation = graphql`
      mutation CommitLineReviewCreateCommentMutation($repoId: ID!, $commitOid: GitObjectID!, $blobOid: GitObjectID!, $hunk: Int!, $line: Int!, $body: String!) {
        createCommitLineReviewComment(repoId: $repoId, commitOid: $commitOid, blobOid: $blobOid, hunk: $hunk, line: $line, body: $body) {
          id
          thread {
            ... on CommitLineReview {
              id
            }
          }
          author {
            login
            avatarUrl
            url
          }
          editable
          deletable
          body
          bodyHtml
          insertedAt
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: response => {
        this.handleCommentCreate(response.createCommitLineReviewComment)
        this.setState({folded: true})
      },
      onError: error => console.error(error)
    })
  }

  handleFormCancel() {
    this.setState({folded: true}, this.destroyComponent)
  }

  handleFormTyping(isTyping) {
    if(this.channel) {
      if(isTyping) {
        this.channel.push("start_typing", {})
      } else {
        this.channel.push("stop_typing", {})
      }
    }
  }

  handleCommentCreate(comment) {
    const {id} = this.props
    if(!id) {
      this.subscribeComments(comment.thread.id)
      this.subscribePresence(comment.thread.id)
    }
    this.setState(state => ({
      comments: state.comments.find(({id}) => id == comment.id) ? state.comments : [...state.comments, comment]
    }))
  }

  handleCommentUpdate(comment) {
    this.setState(state => ({comments: state.comments.map(oldComment => oldComment.id === comment.id ? {...oldComment, ...comment} : oldComment)}))
  }

  handleCommentDelete(comment) {
    if(this.state.comments.find(({id}) => id == comment.id)) {
      this.setState(state => ({comments: state.comments.filter(({id}) => id !== comment.id)}))
      this.destroyComponent()
    }
  }

  destroyComponent() {
    if(this.state.folded && this.state.comments.length === 0) {
      let node = ReactDOM.findDOMNode(this)
      let container = node.closest(".inline-comments")
      ReactDOM.unmountComponentAtNode(node.parentNode)
      container.parentNode.removeChild(container)
      return true
    } else {
      return false
    }
  }
}

export default CommitLineReview
