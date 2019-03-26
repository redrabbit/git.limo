import React from "react"
import ReactDOM from "react-dom"

import {commitMutation, graphql} from "react-relay";

import environment from "../relay-environment"

class InlineCommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.bodyInput = React.createRef()
    this.state = {folded: !!props.reply, submitEnabled: false}
  }

  componentDidUpdate(prevProps, prevState) {
    if(prevState.folded && !this.state.folded) {
      this.bodyInput.current.focus();
    }
  }

  render() {
    if(this.state.folded) {
      return (
        <div className="box">
          <div className="field">
            <div className="control">
              <input name="comment[body]" className="input" placeholder="Leave a comment" ref={this.bodyInput} onFocus={() => this.setState({folded: false})} />
            </div>
          </div>
        </div>
      )
    } else {
      return (
        <div className="box">
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
              <button className="button is-success" disabled={!this.state.submitEnabled} onClick={this.handleSubmit}>Add comment</button>
            </div>
          </div>
        </div>
      )
    }
  }

  handleSubmit() {
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
          }
          body
          insertedAt
        }
      }
    `;

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        console.log(response)
        this.bodyInput.current.value = ""
      },
      onError: err => console.error(err),
    })
  }

  handleCancel() {
    if(this.props.reply) {
      this.setState({folded: true})
    } else {
      let node = ReactDOM.findDOMNode(this)
      let tr = node.closest("tr")
      ReactDOM.unmountComponentAtNode(node.parentNode)
      tr.parentNode.removeChild(tr)
    }
  }
}

export default InlineCommentForm
