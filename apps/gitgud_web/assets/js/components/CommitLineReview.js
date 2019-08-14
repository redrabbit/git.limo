import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery,commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

import {token} from "../auth"

class CommitLineReview extends React.Component {
  constructor(props) {
    super(props)
    this.fetchReview = this.fetchReview.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.renderComments = this.renderComments.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.destroyComponent = this.destroyComponent.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleFormCancel = this.handleFormCancel.bind(this)
    this.handleCommentCreate = this.handleCommentCreate.bind(this)
    this.handleCommentUpdate = this.handleCommentUpdate.bind(this)
    this.handleCommentDelete = this.handleCommentDelete.bind(this)
    this.state = {
      folded: !!props.reviewId,
      repoId: this.props.repoId,
      commitOid: this.props.commitOid,
      blobOid: this.props.blobOid,
      hunk: Number(this.props.hunk),
      line: Number(this.props.line),
      comments: []
    }
  }

  componentDidMount() {
    this.fetchReview()
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
              comments {
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
          comments: response.node.comments
          })
          this.subscribeComments()
        })
    } else {
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

  subscribeComments() {
    this.subscribeCommentCreate()
    this.subscribeCommentUpdate()
    this.subscribeCommentDelete()
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
        {this.renderComments()}
        {token && this.renderForm()}
      </td>
    )
  }

  renderComments() {
    return this.state.comments.map((comment, index) =>
      <Comment key={index} comment={comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
    )
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
      return <CommentForm onSubmit={this.handleFormSubmit} onCancel={this.handleFormCancel} />
    }
  }

  destroyComponent() {
    if(this.state.comments.length === 0) {
      let node = ReactDOM.findDOMNode(this)
      let container = node.closest(".inline-comments")
      ReactDOM.unmountComponentAtNode(node.parentNode)
      container.parentNode.removeChild(container)
      return true
    } else {
      return false
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
    if(!this.destroyComponent()) {
      this.setState({folded: true})
    }
  }

  handleCommentCreate(comment) {
    this.setState(state => ({comments: state.comments.find(oldComment => oldComment.id == comment.id) ? state.comments : [...state.comments, comment]}))
  }

  handleCommentUpdate(comment) {
    this.setState(state => ({comments: state.comments.map(oldComment => oldComment.id === comment.id ? {...oldComment, ...comment} : oldComment)}))
  }
  handleCommentDelete(comment) {
    this.setState(state => ({comments: state.comments.filter(oldComment => oldComment.id !== comment.id)}))
    this.destroyComponent()
  }
}

export default CommitLineReview
