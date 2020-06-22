import React from "react"
import {commitMutation, graphql} from "react-relay"

import environment from "../relay-environment"
import {currentUser} from "../auth"

class CommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.bodyInput = React.createRef()
    this.updatePreview = this.updatePreview.bind(this)
    this.renderActiveTab = this.renderActiveTab.bind(this)
    this.renderSubmitActions = this.renderSubmitActions.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.handleBodyChange = this.handleBodyChange.bind(this)
    this.state = {
      body: props.body || "",
      bodyHtml: props.bodyHtml || "",
      activeTab: "write",
      inputName: this.props.inputName || "comment[body]"
    }
  }

  componentDidMount() {
    if(currentUser) {
      this.bodyInput.current.focus()
      this.bodyInput.current.setSelectionRange(this.bodyInput.current.value.length, this.bodyInput.current.value.length);
    }
  }

  updatePreview() {
    if(this.state.body != "" && this.state.bodyHtml == "") {
      const variables = {
        body: this.state.body,
        repoId: this.props.repoId
      }

      const mutation = graphql`
        mutation CommentFormPreviewMutation($body: String!, $repoId: ID) {
          previewComment(body: $body, repoId: $repoId)
        }
      `
      commitMutation(environment, {
        mutation,
        variables,
        onCompleted: response => this.setState({bodyHtml: response.previewComment}),
        onError: error => console.error(error)
      })
    }
  }

  render() {
    if(currentUser) {
      if(this.props.action != "preview") {
        return (
          <div className="comment-form">
            <header className="tabs is-boxed">
              <ul>
                <li className={this.state.activeTab == "write" ? "is-active" : undefined}>
                  <a onClick={() => this.setState({activeTab: "write"})}>Write</a>
                </li>
                <li className={this.state.activeTab == "preview" ? "is-active" : undefined}>
                  <a onClick={() => this.setState({activeTab: "preview"}, () => this.updatePreview())}>Preview</a>
                </li>
              </ul>
            </header>
            <form onSubmit={this.handleSubmit}>
              <div className="field">
                <div className="control">
                  {this.renderActiveTab()}
                </div>
              </div>
              {this.renderSubmitActions()}
            </form>
          </div>
        )
      } else {
        return (
          <div className="comment-form">
            <header className="tabs is-boxed">
              <ul>
                <li className={this.state.activeTab == "write" ? "is-active" : undefined}>
                  <a onClick={() => this.setState({activeTab: "write"})}>Write</a>
                </li>
                <li className={this.state.activeTab == "preview" ? "is-active" : undefined}>
                  <a onClick={() => this.setState({activeTab: "preview"}, () => this.updatePreview())}>Preview</a>
                </li>
              </ul>
            </header>
            {this.renderActiveTab()}
          </div>
        )
      }
    } else {
      return (
        <div className="comment-form">
          {!this.props.action &&
            <div className="is-pulled-right">
              <button className="delete" onClick={this.props.onCancel}>Cancel</button>
            </div>
          }
          You must <a href={`/login?redirect_to=${encodeURIComponent(window.location.pathname)}`}>login</a> in order to comment.
        </div>
      )
    }
  }

  renderActiveTab() {
    switch(this.state.activeTab) {
      case "write":
        return <textarea name={this.state.inputName} className="textarea" placeholder="Leave a comment" value={this.state.body} onChange={this.handleBodyChange} ref={this.bodyInput} />
      case "preview":
        if(this.state.body != "") {
          if(this.state.bodyHtml != "") {
            return(
              <div className="comment-preview">
                <input type="hidden" name={this.state.inputName} value={this.state.body} ref={this.bodyInput} />
                <div className="content" dangerouslySetInnerHTML={{ __html: this.state.bodyHtml}} />
              </div>
            )
          } else {
            return(
              <div className="comment-preview">
                <input type="hidden" name={this.state.inputName} value={this.state.body} ref={this.bodyInput} />
                <div className="content">Loading preview...</div>
              </div>
            )
          }
        } else {
          return (
            <div className="comment-preview">
              <input type="hidden" name={this.state.inputName} value={this.state.body} ref={this.bodyInput} />
              <div className="content">Nothing to see here.</div>
            </div>
          )
        }
    }
  }

  renderSubmitActions() {
    switch(this.props.action) {
        case "new":
          return (
            <div className="field is-grouped is-grouped-right">
              <div className="control">
                <button className="button is-success" type="submit" disabled={this.state.body === ""}>Add comment</button>
              </div>
            </div>
          )
        case "edit":
          return (
            <div className="field is-grouped is-grouped-right">
              <div className="control">
                <button className="button" type="reset" onClick={this.props.onCancel}>Cancel</button>
              </div>
              <div className="control">
                <button className="button is-link" type="submit" disabled={this.state.body === ""}>Update comment</button>
              </div>
            </div>
          )
        case "reopen":
          return (
            <div className="field is-grouped is-grouped-right">
              <div className="control">
                <button className="button" onClick={this.props.onReopen}>{this.state.body === "" ? "Reopen issue" : "Reopen and comment"}</button>
              </div>
              <div className="control">
                <button className="button is-success" type="submit" disabled={this.state.body === ""}>Add comment</button>
              </div>
            </div>
          )
        case "close":
          return (
            <div className="field is-grouped is-grouped-right">
              <div className="control">
                <button className="button" onClick={this.props.onClose}>{this.state.body === "" ? "Close issue" : "Close and comment"}</button>
              </div>
              <div className="control">
                <button className="button is-success" type="submit" disabled={this.state.body === ""}>Add comment</button>
              </div>
            </div>
          )
        default:
          return (
            <div className="field is-grouped is-grouped-right">
              <div className="control">
                <button className="button" type="reset" onClick={this.handleCancel}>Cancel</button>
              </div>
              <div className="control">
                <button className="button is-success" type="submit" disabled={this.state.body === ""}>Add comment</button>
              </div>
            </div>
          )
      }
  }

  handleSubmit(event) {
    event.preventDefault()
    if(this.props.onTyping) {
      this.props.onTyping(false)
    }
    this.props.onSubmit(this.state.body)
    this.setState({body: "", bodyHtml: ""})
  }

  handleCancel(event) {
    if(this.props.onTyping) {
      if(this.state.body != "") {
        this.props.onTyping(false)
      }
    }
    this.props.onCancel()
    this.setState({body: "", bodyHtml: ""})
  }

  handleBodyChange(event) {
    if(this.props.onTyping) {
      if(event.target.value != "" && this.state.body == "") {
        this.props.onTyping(true)
      } else if(event.target.value == "" && this.state.body != "") {
        this.props.onTyping(false)
      }
    }
    this.setState({body: event.target.value, bodyHtml: ""})
  }
}

export default CommentForm
