import React from "react"

import moment from "moment"

class Comment extends React.Component {
  render() {
    console.log(this.props)
    const {comment} = this.props
    return (
      <div className="box">
        <a className="has-text-black" href={comment.author.url}><img className="avatar is-small" src={comment.author.avatarUrl} width={20} />{comment.author.login}</a> {moment(comment.insertedAt).fromNow()}
        <div className="content" dangerouslySetInnerHTML={{ __html: comment.bodyHtml}} />
      </div>
    )
  }
}

export default Comment

