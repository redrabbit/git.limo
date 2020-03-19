import React from "react"
import ReactDOM from "react-dom"

class CommitSignature extends React.Component {
  render() {
    const {author, committer} = this.props
    if(author.login) {
      if(Object.entries(author).toString() !== Object.entries(committer).toString()) {
        return (
          <div className="tag user is-white">
            <div className="avatar-stack">
              <a href={author.url}><img className="avatar is-small" src={author.avatarUrl} width={24} /></a>
              <a href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={24} /></a>
            </div>
            <a href={author.url}>{author.login}</a>
          </div>
        )
      } else {
        return (
          <a className="tag user is-white" href={author.url}><img className="avatar is-small" src={author.avatarUrl} width={24} />{author.login}</a>
        )
      }
    } else {
      return (
        <a href={`mailto:${author.email}`} className="tag tooltip is-white" data-tooltip={author.email}>{author.name}</a>
      )
    }
  }
}

export default CommitSignature
