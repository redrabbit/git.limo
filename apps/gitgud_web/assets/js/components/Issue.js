import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery, commitMutation, requestSubscription, graphql} from "react-relay"

import moment from "moment"
import {Presence} from "phoenix"

import environment from "../relay-environment"
import socket from "../socket"

import {currentUser} from "../auth"

import Comment from "./Comment"
import CommentForm from "./CommentForm"
import IssueEvent from "./IssueEvent"
import IssueLabelSelect from "./IssueLabelSelect"

class Issue extends React.Component {
  constructor(props) {
    super(props)
    this.titleInput = React.createRef()
    this.fetchIssue = this.fetchIssue.bind(this)
    this.formatTimestamp = this.formatTimestamp.bind(this)
    this.subscriptions = []
    this.channel = null
    this.presence = null
    this.issueCountElement = document.getElementById("issue-count")
    this.subscribePresence = this.subscribePresence.bind(this)
    this.subscribeEvents = this.subscribeEvents.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.incrementGlobalIssueCount = this.incrementGlobalIssueCount.bind(this)
    this.decrementGlobalIssueCount = this.decrementGlobalIssueCount.bind(this)
    this.renderFeed = this.renderFeed.bind(this)
    this.renderStatus = this.renderStatus.bind(this)
    this.renderPresences = this.renderPresences.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleTitleFormSubmit = this.handleTitleFormSubmit.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleLabelsSelection = this.handleLabelsSelection.bind(this)
    this.handleClose = this.handleClose.bind(this)
    this.handleReopen = this.handleReopen.bind(this)
    this.handleFormTyping = this.handleFormTyping.bind(this)
    this.handleCommentCreate = this.handleCommentCreate.bind(this)
    this.handleCommentUpdate = this.handleCommentUpdate.bind(this)
    this.handleCommentDelete = this.handleCommentDelete.bind(this)
    this.state = {
      repoId: null,
      repoLabels: [],
      number: null,
      title: null,
      titleEdit: false,
      author: null,
      status: null,
      insertedAt: null,
      permissions: [],
      comments: [],
      events: [],
      labels: [],
      timestamp: null,
      presences: []
    }
  }

  componentDidMount() {
    this.fetchIssue()
  }

  componentWillUnmount() {
    clearInterval(this.interval)
    this.subscriptions.forEach(subscription => subscription.dispose())
    this.channel.leave()
  }

  fetchIssue() {
    const {issueId} = this.props
    const query = graphql`
      query IssueQuery($id: ID!) {
        node(id: $id) {
          ... on Issue {
            repo {
              id
              issueLabels {
                id
                name
                description
                color
              }
            }
            title
            number
            status
            author {
              login
              url
            }
            insertedAt
            permissions
            comments(first: 50) {
              edges {
                node {
                  id
                  author {
                    login
                    avatarUrl
                    url
                  }
                  editable
                  deletable
                  body
                  bodyHtml
                  insertedAt
                }
              }
            }
            labels {
              id
            }
            events {
              __typename
              timestamp
              ... on IssueCloseEvent {
                user {
                  login
                  url
                }
              }
              ... on IssueReopenEvent {
                user {
                  login
                  url
                }
              }
              ... on IssueTitleUpdateEvent {
                oldTitle
                newTitle
                user {
                  login
                  url
                }
              }
              ... on IssueLabelsUpdateEvent {
                push
                pull
                user {
                  login
                  url
                }
              }
              ... on IssueCommitReferenceEvent {
                commitOid
                commitUrl
                user {
                  login
                  url
                }
              }
            }
          }
        }
      }
    `
    const variables = {
      id: issueId
    }

    fetchQuery(environment, query, variables)
      .then(response => {
        this.setState({
          repoId: response.node.repo.id,
          repoLabels: response.node.repo.issueLabels,
          number: response.node.number,
          title: response.node.title,
          status: response.node.status,
          author: response.node.author,
          insertedAt: response.node.insertedAt,
          permissions: response.node.permissions,
          comments: response.node.comments.edges.map(edge => edge.node),
          labels: response.node.labels.map(label => label.id),
          events: response.node.events,
          timestamp: moment.utc(response.node.insertedAt).fromNow()
        })
        this.interval = setInterval(this.formatTimestamp, 3000)
        this.subscribePresence()
        this.subscribeEvents()
        this.subscribeComments()
      })
  }

  formatTimestamp() {
    this.setState({timestamp: moment.utc(this.state.insertedAt).fromNow()})
  }

  subscribePresence() {
    this.channel = socket.channel(`issue:${this.props.issueId}`)
    this.presence = new Presence(this.channel)
    this.presence.onSync(() => this.setState({presences: this.presence.list()}))
    return this.channel.join()
  }

  subscribeEvents() {
    const {issueId} = this.props
    const subscription = graphql`
      subscription IssueEventSubscription($id: ID!) {
        issueEvent(id: $id) {
          __typename
          timestamp
          ... on IssueCloseEvent {
            user {
              login
              url
            }
          }
          ... on IssueReopenEvent {
            user {
              login
              url
            }
          }
          ... on IssueTitleUpdateEvent {
            oldTitle
            newTitle
            user {
              login
              url
            }
          }
          ... on IssueLabelsUpdateEvent {
            push
            pull
            user {
              login
              url
            }
          }
          ... on IssueCommitReferenceEvent {
            commitOid
            commitUrl
            user {
              login
              url
            }
          }
        }
      }
    `

    const variables = {
      id: issueId
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => {
        const event = response.issueEvent
        switch(event.__typename) {
          case "IssueCloseEvent":
            this.setState(state => ({status: "close", events: [...state.events, event]}))
            this.decrementGlobalIssueCount()
            break
          case "IssueReopenEvent":
            this.setState(state => ({status: "open", events: [...state.events, event]}))
            this.incrementGlobalIssueCount()
            break
          case "IssueTitleUpdateEvent":
            this.setState(state => ({title: event.newTitle, events: [...state.events, event]}))
            break
          case "IssueLabelsUpdateEvent":
            this.setState(state => ({labels: [...state.labels.filter(labelId => !event.pull.includes(labelId)), ...event.push], events: [...state.events, event]}))
            break
          case "IssueCommitReferenceEvent":
            this.setState(state => ({events: [...state.events, event]}))
            break
        }
      },
      onError: error => console.error(error)
    })
  }

  subscribeComments() {
    this.subscriptions.push(this.subscribeCommentCreate())
    this.subscriptions.push(this.subscribeCommentUpdate())
    this.subscriptions.push(this.subscribeCommentDelete())
  }

  subscribeCommentCreate() {
    const {issueId} = this.props
    const subscription = graphql`
      subscription IssueCommentCreateSubscription($id: ID!) {
        issueCommentCreate(id: $id) {
          id
          author {
            login
            avatarUrl
            url
          }
          editable
          deletable
          body
          bodyHtml
          insertedAt
        }
      }
    `

    const variables = {
      id: issueId
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentCreate(response.issueCommentCreate),
      onError: error => console.error(error)
    })
  }

  subscribeCommentUpdate() {
    const {issueId} = this.props
    const subscription = graphql`
      subscription IssueCommentUpdateSubscription($id: ID!) {
        issueCommentUpdate(id: $id) {
          id
          body
          bodyHtml
        }
      }
    `

    const variables = {
      id: issueId
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentUpdate(response.issueCommentUpdate),
      onError: error => console.error(error)
    })
  }

  subscribeCommentDelete() {
    const {issueId} = this.props
    const subscription = graphql`
      subscription IssueCommentDeleteSubscription($id: ID!) {
        issueCommentDelete(id: $id) {
          id
        }
      }
    `

    const variables = {
      id: issueId
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentDelete(response.issueCommentDelete),
      onError: error => console.error(error)
    })
  }

  incrementGlobalIssueCount() {
    this.issueCountElement.textContent = parseInt(this.issueCountElement.textContent) + 1
  }

  decrementGlobalIssueCount() {
    this.issueCountElement.textContent = parseInt(this.issueCountElement.textContent) - 1
  }

  render() {
    const {title, titleEdit, number, insertedAt, author, permissions} = this.state
    if(number) {
      const timestamp = moment.utc(insertedAt)
      return (
        <div>
          <div className="columns">
            <div className="column is-12">
              {titleEdit ? (
                <div className="columns">
                  <div className="column is-12">
                    <form onSubmit={this.handleTitleFormSubmit}>
                      <div className="field is-grouped">
                        <p className="control is-expanded">
                          <input type="text" className="input" name="title" defaultValue={title} ref={this.titleInput} />
                        </p>
                        <p className="control">
                          <button type="submit" className="button is-link">Save</button>
                        </p>
                        <p className="control">
                          <button type="reset" className="button" onClick={() => this.setState({titleEdit: false})}>Cancel</button>
                        </p>
                      </div>
                    </form>
                  </div>
                </div>
              ) : (
                <div className="field is-grouped">
                  <div className="control is-expanded">
                    <h1 className="title">{title} <span className="has-text-grey-light">#{number}</span></h1>
                  </div>
                  {permissions.includes("edit_title") &&
                    <div className="control">
                      <button className="button" onClick={() => this.setState({titleEdit: true})}>Edit</button>
                    </div>
                  }
                </div>
              )}
              {this.renderStatus()}
              &nbsp;
              <a href={author.url} className="has-text-black">{author.login}</a> opened this issue <time className="tooltip" dateTime={timestamp.format()}  data-tooltip={timestamp.format()}>{this.state.timestamp}</time>
            </div>
          </div>

          <hr />

          <div className="columns">
            <div className="column is-three-quarters">
              {this.renderFeed()}
            </div>
            <div className="column is-one-quarter">
              <aside className="menu is-sticky">
                <IssueLabelSelect labels={this.state.repoLabels} selectedLabels={this.state.labels} editable={permissions.includes("edit_labels")} onSubmit={this.handleLabelsSelection} />
              </aside>
            </div>
          </div>
        </div>
      )
    } else {
      return <div></div>
    }
  }

  renderFeed() {
    const repoId = this.state.repoId
    let comments = this.state.comments.slice()
    let events = this.state.events.slice().map(event => {
      switch(event.__typename) {
        case "IssueLabelsUpdateEvent":
          const labelsPush = event.push.map(id => this.state.repoLabels.find(label => label.id == id)).filter(label => !!label)
          const labelsPull = event.pull.map(id => this.state.repoLabels.find(label => label.id == id)).filter(label => !!label)
          return {...event, push: labelsPush, pull: labelsPull}
        default:
          return event
      }
    })
    let firstComment = comments.shift()
    let items = comments.map(comment => ({type: "comment", timestamp: new Date(comment.insertedAt).getTime(), comment: comment}))
    items = items.concat(events.map(event => ({type: "event", timestamp: new Date(event.timestamp).getTime(), event: event})))
    items.sort((a, b) => a.timestamp - b.timestamp)

    return (
      <div className="thread">
        <Comment repoId={repoId} comment={firstComment} onUpdate={this.handleCommentUpdate} deletable={false} />
        <div className="timeline">
          <div className="timeline-header">
            {comments.length == 1 ? "1 comment" : `${comments.length} comments`}
          </div>
          {items.map((item, index) => {
            switch(item.type) {
              case "comment":
                return (
                  <div key={index} className="timeline-item">
                    <div className="timeline-content">
                      <Comment repoId={repoId} comment={item.comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
                    </div>
                  </div>
                )
              case "event":
                return <IssueEvent key={index} event={item.event} />
            }
          })}
          {this.renderPresences()}
          {currentUser &&
            <div className="timeline-item">
              <div className="timeline-content">
                {this.renderForm()}
              </div>
            </div>
          }
        </div>
      </div>
    )
  }

  renderStatus() {
    const {status} = this.state
    switch(status) {
      case "open":
        return <p className="tag is-success"><span className="icon"><i className="fa fa-exclamation-circle"></i></span><span>Open</span></p>
      case "close":
        return <p className="tag is-danger"><span className="icon"><i className="fa fa-check-circle"></i></span><span>Closed</span></p>
    }
  }

  renderPresences() {
    const presences = this.state.presences.filter(({metas}) => metas.some(meta => meta.typing)).map(({user}) => user)
    if(presences.length > 0) {
      return (
        <div className="timeline-item">
          <div className="timeline-marker is-icon">
            <i className="fa fa-i-cursor"></i>
          </div>
          <div className="timeline-content">
            <span className="loading-ellipsis">
              {presences.map((user, i) => [
                i > 0 && (i+1 == presences.length ? " and " : ", "),
                <a key={i} href={user.url} className="has-text-black">{user.login}</a>
              ])}
              {presences.length > 1 ? " are " : " is "} typing
            </span>
          </div>
        </div>
      )
    }
  }

  renderForm() {
    const {status, permissions} = this.state
    if(status == "open") {
      if(permissions.includes("close")) {
        return <CommentForm action="close" repoId={this.state.repoId} onSubmit={this.handleFormSubmit} onTyping={this.handleFormTyping} onClose={this.handleClose} />
      } else {
        return <CommentForm action="new" repoId={this.state.repoId} onTyping={this.handleFormTyping} onSubmit={this.handleFormSubmit} />
      }
    } else {
      if(permissions.includes("reopen")) {
        return <CommentForm action="reopen" repoId={this.state.repoId} onSubmit={this.handleFormSubmit} onTyping={this.handleFormTyping} onReopen={this.handleReopen} />
      } else {
        return <CommentForm action="new" repoId={this.state.repoId} onTyping={this.handleFormTyping} onSubmit={this.handleFormSubmit} />
      }
    }
  }

  handleTitleFormSubmit(event) {
    const {issueId} = this.props
    const title = event.target.title.value
    if(title != "") {
      const variables = {
        id: issueId,
        title: title
      }

      const mutation = graphql`
        mutation IssueUpdateTitleMutation($id: ID!, $title: String!) {
          updateIssueTitle(id: $id, title: $title) {
            title
          }
        }
      `

      commitMutation(environment, {
        mutation,
        variables,
        onCompleted: response => this.setState({title: response.updateIssueTitle.title, titleEdit: false}),
        onError: error => console.error(error)
      })
    }
    event.preventDefault()
  }

  handleFormSubmit(body) {
    if(body != "") {
      const {issueId} = this.props
      const variables = {
        id: issueId,
        body: body
      }

      const mutation = graphql`
        mutation IssueCreateCommentMutation($id: ID!, $body: String!) {
          createIssueComment(id: $id, body: $body) {
            id
            author {
              login
              avatarUrl
              url
            }
            editable
            deletable
            body
            bodyHtml
            insertedAt
          }
        }
      `

      commitMutation(environment, {
        mutation,
        variables,
        onCompleted: response => this.handleCommentCreate(response.createIssueComment),
        onError: error => console.error(error)
      })
    }
  }

  handleLabelsSelection(push, pull) {
    const {issueId} = this.props
    const variables = {
      id: issueId,
      push: push,
      pull: pull
    }

    const mutation = graphql`
      mutation IssueUpdateLabelsMutation($id: ID!, $push: [ID], $pull: [ID]) {
        updateIssueLabels(id: $id, push: $push, pull: $pull) {
          labels {
            id
          }
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: response => this.setState({labels: response.updateIssueLabels.labels.map(label => label.id)}),
      onError: error => console.error(error)
    })
  }

  handleClose() {
    const {issueId} = this.props
    const variables = {
      id: issueId
    }

    const mutation = graphql`
      mutation IssueCloseMutation($id: ID!) {
        closeIssue(id: $id) {
          status
          permissions
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: response => this.setState({status: response.closeIssue.status, permissions: response.closeIssue.permissions}),
      onError: error => console.error(error)
    })
  }

  handleReopen() {
    const {issueId} = this.props
    const variables = {
      id: issueId
    }

    const mutation = graphql`
      mutation IssueReopenMutation($id: ID!) {
        reopenIssue(id: $id) {
          status
          permissions
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: response => this.setState({status: response.reopenIssue.status, permissions: response.reopenIssue.permissions}),
      onError: error => console.error(error)
    })
  }

  handleFormTyping(isTyping) {
    if(isTyping) {
      this.channel.push("start_typing", {})
    } else {
      this.channel.push("stop_typing", {})
    }
  }

  handleCommentCreate(comment) {
    this.setState(state => ({comments: state.comments.find(({id}) => id == comment.id) ? state.comments : [...state.comments, comment]}))
  }

  handleCommentUpdate(comment) {
    this.setState(state => ({comments: state.comments.map(oldComment => oldComment.id === comment.id ? {...oldComment, ...comment} : oldComment)}))
  }
  handleCommentDelete(comment) {
    if(this.state.comments.find(({id}) => id == comment.id)) {
      this.setState(state => ({comments: state.comments.filter(({id}) => id !== comment.id)}))
    }
  }
}

export default Issue
