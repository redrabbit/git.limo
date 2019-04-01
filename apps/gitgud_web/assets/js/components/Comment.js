import React from "react"

import {commitMutation, graphql} from "react-relay";

import environment from "../relay-environment"

import moment from "moment"

class Comment extends React.Component {
  render() {
    const {comment} = this.props
    return (
      <div className="comment">
        <div className="buttons is-pulled-right">
          <button className="button is-small">
            <span className="icon is-small">
              <i className="fa fa-pen"></i>
            </span>
          </button>
          <button className="button is-small" onClick={() => this.props.onDeleteClick(this.props.comment)}>
            <span className="icon is-small">
              <i className="fa fa-trash"></i>
            </span>
          </button>
        </div>
        <a className="has-text-black" href={comment.author.url}><img className="avatar is-small" src={comment.author.avatarUrl} width={20} />{comment.author.login}</a> {moment.utc(comment.insertedAt).fromNow()}
        <div className="content" dangerouslySetInnerHTML={{ __html: comment.bodyHtml}} />
      </div>
    )
  }

  static deleteComment(commentId, onComplete, onError) {
    const variables = {
      comment: commentId
    }

    const mutation = graphql`
      mutation CommentDeleteCommentMutation($comment: ID!) {
        deleteComment(comment: $comment) {
          id
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: onComplete,
      onError: onError
    })
  }
}

export default Comment

