import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery,commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"
import socket from "../socket"

import {Presence} from "phoenix"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

class CommitLineReview extends React.Component {
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
    this.destroyComponent = this.destroyComponent.bind(this)
    this.state = {
      folded: !!props.reviewId,
      repoId: this.props.repoId,
      commitOid: this.props.commitOid,
      blobOid: this.props.blobOid,
      hunk: Number(this.props.hunk),
      line: Number(this.props.line),
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
    this.state.channel.leave()
    this.subscriptions.forEach(subscription => subscription.dispose())
  }

  fetchReview() {
    const {reviewId} = this.props
    if(reviewId) {
      const query = graphql`
        query CommitLineReviewQuery($id: ID!) {
          node(id: $id) {
            ... on CommitLineReview {
              repo {
                id
              }
              commitOid
              blobOid
              hunk
              line
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
          blobOid: response.node.blobOid,
          hunk: response.node.hunk,
          line: response.node.line,
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

  static subscribeNewLineReviews(repoId, commitOid, config) {
    const subscription = graphql`
      subscription CommitLineReviewCreateSubscription($repoId: ID!, $commitOid: GitObjectID!) {
        commitLineReviewCreate(repoId: $repoId, commitOid: $commitOid) {
          id
          blobOid
          hunk
          line
        }
      }
    `

    const variables = {
      repoId: repoId,
      commitOid: commitOid,
    }

    return requestSubscription(environment, {...config, ...{subscription, variables}})
  }

  subscribePresence() {
    let channel = socket.channel(`commit_line_review:${this.state.repoId}:${this.state.commitOid}:${this.state.blobOid}:${this.state.hunk}:${this.state.line}`)
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
      subscription CommitLineReviewCommentCreateSubscription(
        $repoId: ID!,
        $commitOid: GitObjectID!,
        $blobOid: GitObjectID!,
        $hunk: Int!,
        $line: Int!
      ) {
        commitLineReviewCommentCreate(repoId: $repoId, commitOid: $commitOid, blobOid: $blobOid, hunk: $hunk, line: $line) {
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
      commitOid: this.state.commitOid,
      blobOid: this.state.blobOid,
      hunk: this.state.hunk,
      line: this.state.line
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentCreate(response.commitLineReviewCommentCreate),
    })
  }

  subscribeCommentUpdate() {
    const {comment} = this.props
    const subscription = graphql`
      subscription CommitLineReviewCommentUpdateSubscription(
        $repoId: ID!,
        $commitOid: GitObjectID!,
        $blobOid: GitObjectID!,
        $hunk: Int!,
        $line: Int!
      ) {
        commitLineReviewCommentUpdate(repoId: $repoId, commitOid: $commitOid, blobOid: $blobOid, hunk: $hunk, line: $line) {
          id
          body
          bodyHtml
        }
      }
    `

    const variables = {
      repoId: this.state.repoId,
      commitOid: this.state.commitOid,
      blobOid: this.state.blobOid,
      hunk: this.state.hunk,
      line: this.state.line
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentUpdate(response.commitLineReviewCommentUpdate)
    })
  }

  subscribeCommentDelete() {
    const {comment} = this.props
    const subscription = graphql`
      subscription CommitLineReviewCommentDeleteSubscription(
        $repoId: ID!,
        $commitOid: GitObjectID!,
        $blobOid: GitObjectID!,
        $hunk: Int!,
        $line: Int!
      ) {
        commitLineReviewCommentDelete(repoId: $repoId, commitOid: $commitOid, blobOid: $blobOid, hunk: $hunk, line: $line) {
          id
        }
      }
    `

    const variables = {
      repoId: this.state.repoId,
      commitOid: this.state.commitOid,
      blobOid: this.state.blobOid,
      hunk: this.state.hunk,
      line: this.state.line
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentDelete(response.commitLineReviewCommentDelete)
    })
  }

  render() {
    return (
      <td colSpan={4}>
        <div className="timeline">
          {this.renderComments()}
          {this.renderPresences()}
          <div className="timeline-item">
            <div className="timeline-content">
              {this.renderForm()}
            </div>
          </div>
        </div>
      </td>
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
      blobOid: this.state.blobOid,
      hunk: this.state.hunk,
      line: this.state.line,
      body: body
    }

    const mutation = graphql`
      mutation CommitLineReviewCreateCommentMutation($repoId: ID!, $commitOid: GitObjectID!, $blobOid: GitObjectID!, $hunk: Int!, $line: Int!, $body: String!) {
        createCommitLineReviewComment(repoId: $repoId, commitOid: $commitOid, blobOid: $blobOid, hunk: $hunk, line: $line, body: $body) {
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

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        this.handleCommentCreate(response.createCommitLineReviewComment)
        this.setState({folded: true})
      }
    })
  }

  handleFormCancel() {
    this.setState({folded: true}, this.destroyComponent)
  }

  handleFormTyping(isTyping) {
    if(this.state.channel) {
      if(isTyping) {
        this.state.channel.push("start_typing", {})
      } else {
        this.state.channel.push("stop_typing", {})
      }
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
