import React from "react"
import {fetchQuery, commitMutation, graphql} from "react-relay"

import ReactTextareaAutocomplete from "@webscopeio/react-textarea-autocomplete"
import emoji from "@jukben/emoji-search"

import environment from "../relay-environment"
import {currentUser} from "../auth"

class CommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.searchUserMention = this.searchUserMention.bind(this)
    this.updatePreview = this.updatePreview.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.renderActiveTab = this.renderActiveTab.bind(this)
    this.renderSubmitActions = this.renderSubmitActions.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.handleBodyChange = this.handleBodyChange.bind(this)
    this.state = {
      body: props.body || "",
      bodyHtml: props.bodyHtml || "",
      activeTab: "form",
      inputName: this.props.inputName || "comment[body]"
    }
  }

  componentDidMount() {
    if(currentUser) {
      this.bodyInput.focus()
      this.bodyInput.setSelectionRange(this.bodyInput.value.length, this.bodyInput.value.length);
    }
  }

  searchUserMention(input) {
    const query = graphql`
      query CommentFormMentionQuery($input: String!) {
        search(user: $input, first:10) {
          edges {
            node {
              ... on User {
                id
                login
                avatarUrl
              }
            }
          }
        }
      }
    `

    const variables = {
      input: input
    }

    return new Promise((resolve, reject) => {
      fetchQuery(environment, query, variables)
        .then(response => resolve(response.search.edges.map(({node}) => node)))
    })
  }

  updatePreview() {
    if(this.state.body != "" && this.state.bodyHtml == "") {
      const mutation = graphql`
        mutation CommentFormPreviewMutation($body: String!, $repoId: ID) {
          previewComment(body: $body, repoId: $repoId)
        }
      `

      const variables = {
        body: this.state.body,
        repoId: this.props.repoId
      }

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
      return (
        <div className="comment-form">
          <header className="tabs is-boxed">
            <ul>
              <li className={this.state.activeTab == "form" ? "is-active" : undefined}>
                <a onClick={() => this.setState({activeTab: "form"})}>Write</a>
              </li>
              <li className={this.state.activeTab == "preview" ? "is-active" : undefined}>
                <a onClick={() => this.setState({activeTab: "preview"}, () => this.updatePreview())}>Preview</a>
              </li>
            </ul>
          </header>
          {this.props.embedded ? this.renderActiveTab() : this.renderForm()}
        </div>
      )
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

  renderForm() {
    return (
      <form onSubmit={this.handleSubmit}>
        <div className="field">
          <div className="control">
            {this.renderActiveTab()}
          </div>
        </div>
        {this.renderSubmitActions()}
      </form>
    )
  }

  renderActiveTab() {
    switch(this.state.activeTab) {
      case "form":
        return (
          <ReactTextareaAutocomplete
            loadingComponent={() => <span className="loading-ellipsis">Loading</span>}
            innerRef={textarea => this.bodyInput = textarea}
            required={true}
            name={this.state.inputName}
            className="textarea"
            dropdownClassName="dropdown is-active"
            listClassName="dropdown-content"
            value={this.state.body}
            onChange={this.handleBodyChange}
            trigger={{
              ":": {
                dataProvider: token => emoji(token).slice(0, 5),
                component: ({ entity: { name, char } }) => <a className="dropdown-item">{`${char} ${name}`}</a>,
                output: emoji => emoji.char
              },
              "@": {
                dataProvider: this.searchUserMention,
                component: ({ entity: { login, avatarUrl } }) =>
                  <a className="dropdown-item">
                    <span className="tag user is-white">
                      <img className="avatar is-small" src={avatarUrl} width={24} />{login}
                    </span>
                  </a>,
                output: (user, trigger) => trigger + user.login
              }
            }}
          />
        )
      case "preview":
        if(this.state.body != "") {
          if(this.state.bodyHtml != "") {
            return(
              <div className="comment-preview">
                <input type="hidden" name={this.state.inputName} value={this.state.body} />
                <div className="content" dangerouslySetInnerHTML={{ __html: this.state.bodyHtml}} />
              </div>
            )
          } else {
            return(
              <div className="comment-preview">
                <input type="hidden" name={this.state.inputName} value={this.state.body} />
                <div className="content">Loading preview...</div>
              </div>
            )
          }
        } else {
          return (
            <div className="comment-preview">
              <input type="hidden" name={this.state.inputName} value={this.state.body} />
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
        case "edit":
          return (
            <div className="field is-grouped is-grouped-right">
              <div className="control">
                <button className="button" type="reset" onClick={this.props.onCancel}>Cancel</button>
              </div>
              <div className="control">
                <button className="button is-link" type="submit" disabled={this.state.body === "" || this.state.body === this.props.body}>Update comment</button>
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
