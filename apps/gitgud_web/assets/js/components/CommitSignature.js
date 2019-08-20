import React from "react"
import ReactDOM from "react-dom"

class CommitSignature extends React.Component {
  render() {
    const {author, committer} = this.props
    if(committer.login) {
      if(author.login && author.login !== committer.login) {
        return (
          <div className="tag user is-white">
            <div className="avatar-stack">
              <a href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={24} /></a>
              <a href={author.url}><img className="avatar is-small" src={author.avatarUrl} width={24} /></a>
            </div>
            <a href={committer.url}>{committer.login}</a>
          </div>
        )
      } else {
        return (
          <a className="tag user is-white" href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={24} />{committer.login}</a>
        )
      }
    } else {
      return (
        <a href={`mailto:${committer.email}`} className="tag tooltip is-white" data-tooltip={committer.email}>{committer.name}</a>
      )
    }
  }
}

export default CommitSignature
