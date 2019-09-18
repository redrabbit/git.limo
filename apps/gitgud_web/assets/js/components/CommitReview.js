import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery,commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"
import socket from "../socket"

import {Presence} from "phoenix"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

class CommitReview extends React.Component {
  constructor(props) {
    super(props)
    this.fetchReview = this.fetchReview.bind(this)
    this.subscriptions = []
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
    this.state = {
      folded: true,
      repoId: this.props.repoId,
      commitOid: this.props.commitOid,
      comments: [],
      channel: null,
      presence: null,
      presences: []
    }
  }

  componentDidMount() {
    this.fetchReview()
  }

  componentWillUnmount() {
    this.channel.leave()
    this.subscriptions.forEach(subscription => subscription.dispose())
  }

  fetchReview() {
    const {reviewId} = this.props
    if(reviewId) {
      const query = graphql`
        query CommitReviewQuery($id: ID!) {
          node(id: $id) {
            ... on CommitReview {
              repo {
                id
              }
              commitOid
              comments(first: 50) {
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
        id: reviewId
      }

      fetchQuery(environment, query, variables)
        .then(response => {
          this.setState({
          repoId: response.node.repo.id,
          commitOid: response.node.commitOid,
          comments: response.node.comments.edges.map(edge => edge.node)
          })
          this.subscribePresence()
          this.subscribeComments()
        })
    } else {
      this.subscribePresence()
      this.subscribeComments()
    }
  }

  subscribePresence() {
    let channel = socket.channel(`commit_review:${this.state.repoId}:${this.state.commitOid}`)
    let presence = new Presence(channel)
    presence.onSync(() => this.setState({presences: presence.list()}))
    this.setState({channel: channel, presence: presence})
    return channel.join()
  }

  subscribeComments() {
    this.subscriptions.push(this.subscribeCommentCreate())
    this.subscriptions.push(this.subscribeCommentUpdate())
    this.subscriptions.push(this.subscribeCommentDelete())
  }

  subscribeCommentCreate() {
    const subscription = graphql`
      subscription CommitReviewCommentCreateSubscription($repoId: ID!, $commitOid: GitObjectID!) {
        commitReviewCommentCreate(repoId: $repoId, commitOid: $commitOid) {
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
      repoId: this.state.repoId,
      commitOid: this.state.commitOid
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentCreate(response.commitReviewCommentCreate),
    })
  }

  subscribeCommentUpdate() {
    const subscription = graphql`
      subscription CommitReviewCommentUpdateSubscription($repoId: ID!, $commitOid: GitObjectID!) {
        commitReviewCommentUpdate(repoId: $repoId, commitOid: $commitOid) {
          id
          body
          bodyHtml
        }
      }
    `

    const variables = {
      repoId: this.state.repoId,
      commitOid: this.state.commitOid
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentUpdate(response.commitReviewCommentUpdate)
    })
  }

  subscribeCommentDelete() {
    const subscription = graphql`
      subscription CommitReviewCommentDeleteSubscription($repoId: ID!, $commitOid: GitObjectID!) {
        commitReviewCommentDelete(repoId: $repoId, commitOid: $commitOid) {
          id
        }
      }
    `

    const variables = {
      repoId: this.state.repoId,
      commitOid: this.state.commitOid
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentDelete(response.commitReviewCommentDelete)
    })
  }

  render() {
    const {comments} = this.state
    return (
      <div className="thread">
        <div className="timeline">
          <div className="timeline-header">
            {comments.length == 1 ? "1 comment" : `${comments.length} comments`}
          </div>
          {this.renderComments()}
          {this.renderPresences()}
          <div className="timeline-item">
            <div className="timeline-content">
              {this.renderForm()}
            </div>
          </div>
        </div>
      </div>
    )
  }

  renderComments() {
    return this.state.comments.map((comment, index) =>
      <div key={index} className="timeline-item">
        <div className="timeline-content">
          <Comment comment={comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
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
      return <CommentForm onSubmit={this.handleFormSubmit} onTyping={this.handleFormTyping} onCancel={this.handleFormCancel} />
    }
  }

  handleFormSubmit(body) {
    const variables = {
      repoId: this.state.repoId,
      commitOid: this.state.commitOid,
      body: body
    }

    const mutation = graphql`
      mutation CommitReviewCreateCommentMutation($repoId: ID!, $commitOid: GitObjectID!, $body: String!) {
        createCommitReviewComment(repoId: $repoId, commitOid: $commitOid, body: $body) {
          id
          author {
            login
            avatarUrl
            url
          }
          editable
          body
          bodyHtml
          insertedAt
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        this.handleCommentCreate(response.createCommitReviewComment)
        this.setState({folded: true})
      }
    })
  }

  handleFormCancel() {
    this.setState({folded: true})
  }

  handleFormTyping(isTyping) {
    if(isTyping) {
      this.state.channel.push("start_typing", {})
    } else {
      this.state.channel.push("stop_typing", {})
    }
  }

  handleCommentCreate(comment) {
    this.setState(state => ({comments: state.comments.find(({id}) => id == comment.id) ? state.comments : [...state.comments, comment]}))
  }

  handleCommentUpdate(comment) {
    this.setState(state => ({comments: state.comments.map(oldComment => oldComment.id === comment.id ? {...oldComment, ...comment} : oldComment)}))
  }
  handleCommentDelete(comment) {
    if(this.state.comments.find(({id}) => id == comment.id)) {
      this.setState(state => ({comments: state.comments.filter(({id}) => id !== comment.id)}))
    }
  }
}

export default CommitReview
