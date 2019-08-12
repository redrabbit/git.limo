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
    this.subscribeUpdate = this.subscribeUpdate.bind(this)
    this.subscribeDelete = this.subscribeDelete.bind(this)
    this.highlightCodeFences = this.highlightCodeFences.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.handleCancel = this.handleCancel.bind(this)
    this.handleUpdateClick = this.handleUpdateClick.bind(this)
    this.handleDeleteClick = this.handleDeleteClick.bind(this)
    this.updateSubscription = this.subscribeUpdate()
    this.deleteSubscription = this.subscribeDelete()
    this.state = {edit: false}
  }

  componentDidMount() {
    this.highlightCodeFences()
  }

  componentDidUpdate() {
    this.highlightCodeFences()
  }

  componentWillUnmount() {
    this.updateSubscription.dispose()
    this.deleteSubscription.dispose()
  }

  render() {
    const {comment} = this.props
    if(this.state.edit) {
      return <CommentForm body={comment.body} action="edit" onSubmit={this.handleSubmit} onCancel={this.handleCancel} />
    } else {
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
          <a className="has-text-black" href={comment.author.url}><img className="avatar is-small" src={comment.author.avatarUrl} width={20} />{comment.author.login}</a> {moment.utc(comment.insertedAt).fromNow()}
          </header>
          <div className="content" dangerouslySetInnerHTML={{ __html: comment.bodyHtml}} ref={this.body} />
        </div>
      )
    }
  }

  subscribeUpdate() {
    const {comment} = this.props
    const subscription = graphql`
      subscription CommentUpdateSubscription($commentId: ID!) {
        commentUpdate(id: $commentId) {
          id
          body
          bodyHtml
        }
      }
    `

    const variables = {
      commentId: comment.id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.props.onUpdate(response.commentUpdate)
    })
  }

  subscribeDelete() {
    const {comment} = this.props
    const subscription = graphql`
      subscription CommentDeleteSubscription($commentId: ID!) {
        commentDelete(id: $commentId) {
          id
        }
      }
    `

    const variables = {
      commentId: comment.id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.props.onDelete(response.commentDelete)
    })
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
