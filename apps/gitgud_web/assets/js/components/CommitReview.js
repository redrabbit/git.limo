import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery,commitMutation, graphql} from "react-relay";

import environment from "../relay-environment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

import {token} from "../auth"

class CommitReview extends React.Component {
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
      folded: true,
      repoId: this.props.repoId,
      commitOid: this.props.commitOid,
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
        query CommitReviewQuery($id: ID!) {
          node(id: $id) {
            ... on CommitReview {
              repo {
                id
              }
              commitOid
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
          comments: response.node.comments
          })
        })
    }
  }

  destroyComponent() {
    return false
  }

  render() {
    return (
      <div className="inline-comments">
        <header>
          <h2 className="subtitle">{this.state.comments.length == 1 ? "1 comment" : `${this.state.comments.length} comments`}</h2>
        </header>
        {this.renderComments()}
        {token && this.renderForm()}
      </div>
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
      body: body
    }

    const mutation = graphql`
      mutation CommitReviewCreateCommentMutation($repoId: ID!, $commitOid: GitObjectID!, $body: String!) {
        createCommitComment(repoId: $repoId, commitOid: $commitOid, body: $body) {
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

export default CommitReview
