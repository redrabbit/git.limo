import React from "react"
import ReactDOM from "react-dom"

import moment from "moment"

import {commitMutation, graphql} from "react-relay";

import environment from "../relay-environment"

class InlineCommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.renderForm = this.renderForm.bind(this)
    this.renderComments = this.renderComments.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.bodyInput = React.createRef()
    this.commentsContainer = document.createElement("div")
    this.commentsContainer.classList.add("comments")
    this.state = {folded: !!props.draft, draft: !!!props.draft, submitEnabled: false, comments: []}
  }

  componentDidMount() {
    let root = ReactDOM.findDOMNode(this).parentNode
    root.parentNode.insertBefore(this.commentsContainer, root)
  }

  componentDidUpdate(prevProps, prevState) {
    if(prevState.folded && !this.state.folded) {
      this.bodyInput.current.focus();
    }
  }

  componentWillUnmount() {
    let root = ReactDOM.findDOMNode(this).parentNode
    root.parentNode.removeChild(this.commentsContainer)
  }

  render() {
    return (
      <div className="box">
        {this.renderForm()}
        {this.renderComments()}
      </div>
    )
  }

  renderComments() {
    return ReactDOM.createPortal(
      this.state.comments.map((comment, index) => {
        return (
          <div className="box" key={index}>
            <a className="has-text-black" href={comment.author.url}>{comment.author.login}</a> {moment(comment.insertedAt).fromNow()}
            <p>{comment.body}</p>
          </div>
        )
      }), this.commentsContainer)
  }

  renderForm() {
    if(this.state.folded) {
      return (
        <form>
          <div className="field">
            <div className="control">
              <input name="comment[body]" className="input" placeholder="Leave a comment" ref={this.bodyInput} onFocus={() => this.setState({folded: false})} />
            </div>
          </div>
        </form>
      )
    } else {
      return (
        <form>
          <div className="field">
            <div className="control">
              <textarea name="comment[body]"className="textarea" placeholder="Leave a comment" ref={this.bodyInput} onChange={(event) => this.setState({submitEnabled: !!event.target.value})} />
            </div>
          </div>
          <div className="field is-grouped">
            <div className="control">
              <button className="button" onClick={this.handleCancel}>Cancel</button>
            </div>
            <div className="control">
              <button className="button is-success" type="submit" disabled={!this.state.submitEnabled} onClick={this.handleSubmit}>Add comment</button>
            </div>
          </div>
        </form>
      )
    }
  }

  handleSubmit(event) {
    const variables = {
      repo: this.props.repo,
      commit: this.props.commit,
      blob: this.props.blob,
      hunk: Number(this.props.hunk),
      line: Number(this.props.line),
      body: this.bodyInput.current.value
    }

    const mutation = graphql`
      mutation InlineCommentFormAddCommentMutation($repo: ID!, $commit: GitObjectID!, $blob: GitObjectID!, $hunk: Int!, $line: Int!, $body: String!) {
        addGitCommitComment(repo: $repo, commit: $commit, blob: $blob, hunk: $hunk, line: $line, body: $body) {
          author {
            login
            url
          }
          body
          insertedAt
        }
      }
    `

    event.preventDefault()
    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        let comment = <div className="box" key={12}>hello</div>
        this.setState(state => ({draft: false, comments: [...state.comments, response.addGitCommitComment]}))
        this.bodyInput.current.value = ""
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

export default InlineCommentForm
