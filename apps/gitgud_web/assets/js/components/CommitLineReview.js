import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery,commitMutation, graphql} from "react-relay";

import environment from "../relay-environment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

import {token} from "../auth"

class CommitLineReview extends React.Component {
  constructor(props) {
    super(props)
    this.fetchReview = this.fetchReview.bind(this)
    this.destroyComponent = this.destroyComponent.bind(this)
    this.renderComments = this.renderComments.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleFormCancel = this.handleFormCancel.bind(this)
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
        .then(response => this.setState({
          repoId: response.node.repo.id,
          commitOid: response.node.commitOid,
          blobOid: response.node.blobOid,
          hunk: response.node.hunk,
          line: response.node.line,
          comments: response.node.comments
        }))
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
        createCommitComment(repoId: $repoId, commitOid: $commitOid, blobOid: $blobOid, hunk: $hunk, line: $line, body: $body) {
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
        this.setState(state => ({folded: true, comments: [...state.comments, response.createCommitComment]}))
      }
    })
  }

  handleFormCancel() {
    if(!this.destroyComponent()) {
      this.setState({folded: true})
    }
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
