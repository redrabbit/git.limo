import React from "react"
import ReactDOM from "react-dom"

import {commitMutation, graphql} from "react-relay";

import environment from "../relay-environment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

class CommitLineReview extends React.Component {
  constructor(props) {
    super(props)
    this.commentsContainer = document.createElement("div")
    this.commentsContainer.classList.add("comments")
    this.renderComments = this.renderComments.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.state = {folded: !!props.reply, draft: !!!props.reply, submitEnabled: false, comments: []}
  }

  componentDidMount() {
    let root = ReactDOM.findDOMNode(this).parentNode
    root.parentNode.insertBefore(this.commentsContainer, root)
  }

  componentWillUnmount() {
    let root = ReactDOM.findDOMNode(this).parentNode
    root.parentNode.removeChild(this.commentsContainer)
  }

  render() {
    return (
      <div className="box">
        {this.renderComments()}
        {this.renderForm()}
      </div>
    )
  }

  renderComments() {
    return ReactDOM.createPortal(
      this.state.comments.map((comment, index) => <Comment key={index} comment={comment} />), this.commentsContainer)
  }

  renderForm() {
    if(this.state.folded) {
      return (
        <form>
          <div className="field">
            <div className="control">
              <input name="comment[body]" className="input" placeholder="Leave a comment" onFocus={() => this.setState({folded: false})} />
            </div>
          </div>
        </form>
      )
    } else {
      return <CommentForm onSubmit={this.handleSubmit} onCancel={this.handleCancel} />
    }
  }

  handleSubmit(body) {
    const variables = {
      repo: this.props.repo,
      commit: this.props.commit,
      blob: this.props.blob,
      hunk: Number(this.props.hunk),
      line: Number(this.props.line),
      body: body
    }

    const mutation = graphql`
      mutation CommitLineReviewAddCommentMutation($repo: ID!, $commit: GitObjectID!, $blob: GitObjectID!, $hunk: Int!, $line: Int!, $body: String!) {
        addGitCommitComment(repo: $repo, commit: $commit, blob: $blob, hunk: $hunk, line: $line, body: $body) {
          id
          author {
            login
            avatarUrl
            url
          }
          bodyHtml
          insertedAt
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        this.setState(state => ({draft: false, comments: [...state.comments, response.addGitCommitComment]}))
      },
      onError: err => console.error(err)
    })
  }

  handleCancel() {
    if(this.state.draft) {
      let node = ReactDOM.findDOMNode(this)
      let container = node.closest(".inline-comments")
      ReactDOM.unmountComponentAtNode(node.parentNode)
      container.parentNode.removeChild(container)
    } else {
      this.setState({folded: true})
    }
  }
}

export default CommitLineReview
