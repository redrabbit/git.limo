import React from "react"

import hljs from "highlight.js"

import {commitMutation, requestSubscription, graphql} from "react-relay"

import moment from "moment"

import environment from "../relay-environment"

import CommentForm from "./CommentForm"

class Comment extends React.Component {
  constructor(props) {
    super(props)
    this.body = React.createRef()
    this.formatTimestamp = this.formatTimestamp.bind(this)
    this.highlightCodeFences = this.highlightCodeFences.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.handleUpdateClick = this.handleUpdateClick.bind(this)
    this.handleDeleteClick = this.handleDeleteClick.bind(this)
    this.state = {edit: false, timestamp: moment.utc(this.props.comment.insertedAt).fromNow()}
  }

  componentDidMount() {
    this.highlightCodeFences()
    this.interval = setInterval(this.formatTimestamp, 3000)
  }

  componentDidUpdate() {
    this.highlightCodeFences()
  }

  componentWillUnmount() {
    clearInterval(this.interval)
  }

  render() {
    const {comment} = this.props
    if(this.state.edit) {
      return <CommentForm body={comment.body} action="edit" onSubmit={this.handleSubmit} onCancel={this.handleCancel} />
    } else {
      const timestamp = moment.utc(comment.insertedAt)
      return (
        <div className="comment">
          <header className="comment-header">
            {comment.editable &&
              <div className="buttons is-pulled-right">
                <button className="button is-small" onClick={this.handleUpdateClick}>
                  <span className="icon is-small">
                    <i className="fa fa-pen"></i>
                  </span>
                </button>
                <button className="button is-small" onClick={this.handleDeleteClick}>
                  <span className="icon is-small">
                    <i className="fa fa-trash"></i>
                  </span>
                </button>
              </div>
            }
            <a className="tag user" href={comment.author.url}><img className="avatar is-small" src={comment.author.avatarUrl} width={24} />{comment.author.login}</a> commented <time className="tooltip" date-time={timestamp.format()}  data-tooltip={timestamp.format()}>{this.state.timestamp}</time>
          </header>
          <div className="content" dangerouslySetInnerHTML={{ __html: comment.bodyHtml}} ref={this.body} />
        </div>
      )
    }
  }

  formatTimestamp() {
    this.setState({timestamp: moment.utc(this.props.comment.insertedAt).fromNow()})
  }

  highlightCodeFences() {
    if(this.body.current) {
      this.body.current.querySelectorAll("pre code").forEach(code => hljs.highlightBlock(code))
    }
  }

  handleSubmit(body) {
    const variables = {id: this.props.comment.id, body: body}
    const mutation = graphql`
      mutation CommentUpdateMutation($id: ID!, $body: String!) {
        updateComment(id: $id, body: $body) {
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
    commitMutation(environment, {mutation, variables, onCompleted: response => {
      this.props.onUpdate(response.updateComment)
      this.setState({edit: false})
    }})
  }

  handleCancel() {
    this.setState({edit: false})
  }

  handleUpdateClick() {
    this.setState(state => ({edit: !state.edit}))
  }

  handleDeleteClick() {
    const variables = {id: this.props.comment.id}
    const mutation = graphql`
      mutation CommentDeleteMutation($id: ID!) {
        deleteComment(id: $id) {
          id
        }
      }
    `
    commitMutation(environment, {mutation, variables, onCompleted: response => this.props.onDelete(response.deleteComment)})
  }
}

export default Comment
