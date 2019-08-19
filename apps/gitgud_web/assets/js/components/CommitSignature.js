import React from "react"
import ReactDOM from "react-dom"

class CommitSignature extends React.Component {
  render() {
    const {author, committer} = this.props
    if(committer.login) {
      if(author.login && author.login !== committer.login) {
        return (
          <div className="avatar-stack">
            <a className="has-text-black" href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={20} />{committer.login}</a>
            <a className="has-text-black" href={author.url}><img className="avatar is-small" src={author.avatarUrl} width={20} />{author.login}</a>
          </div>
        )
      } else {
        return (
          <a className="has-text-black" href={committer.url}><img className="avatar is-small" src={committer.avatarUrl} width={20} />{committer.login}</a>
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
