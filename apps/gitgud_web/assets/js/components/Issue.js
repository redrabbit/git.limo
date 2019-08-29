import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery, commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"

import moment from "moment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"
import IssueEvent from "./IssueEvent"

class Issue extends React.Component {
  constructor(props) {
    super(props)
    this.titleInput = React.createRef()
    this.fetchIssue = this.fetchIssue.bind(this)
    this.formatTimestamp = this.formatTimestamp.bind(this)
    this.subscribeEvents = this.subscribeEvents.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.renderFeed = this.renderFeed.bind(this)
    this.renderStatus = this.renderStatus.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleTitleFormSubmit = this.handleTitleFormSubmit.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleClose = this.handleClose.bind(this)
    this.handleReopen = this.handleReopen.bind(this)
    this.handleCommentCreate = this.handleCommentCreate.bind(this)
    this.handleCommentUpdate = this.handleCommentUpdate.bind(this)
    this.handleCommentDelete = this.handleCommentDelete.bind(this)
    this.state = {}
    this.state = {
      title: null,
      titleEdit: false,
      author: null,
      status: null,
      number: null,
      insertedAt: null,
      editable: false,
      comments: [],
      events: [],
      timestamp: null
    }
  }

  componentDidMount() {
    this.fetchIssue()
  }

  fetchIssue() {
    const query = graphql`
      query IssueQuery($id: ID!) {
        node(id: $id) {
          ... on Issue {
            title
            number
            status
            author {
              login
              url
            }
            insertedAt
            editable
            comments {
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
            events {
              type
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
            }
          }
        }
      }
    `
    const variables = {
      id: this.props.id
    }

    fetchQuery(environment, query, variables)
      .then(response => {
        this.setState({
          title: response.node.title,
          number: response.node.number,
          status: response.node.status,
          author: response.node.author,
          insertedAt: response.node.insertedAt,
          editable: response.node.editable,
          comments: response.node.comments,
          events: response.node.events,
          timestamp: moment.utc(response.node.insertedAt).fromNow()
        })
        this.interval = setInterval(this.formatTimestamp, 3000)
        this.subscribeEvents()
        this.subscribeComments()
      })
  }

  formatTimestamp() {
    this.setState({timestamp: moment.utc(this.state.insertedAt).fromNow()})
  }

  subscribeEvents() {
    const subscription = graphql`
      subscription IssueEventSubscription($id: ID!) {
        issueEvent(id: $id) {
          type
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
        }
      }
    `

    const variables = {
      id: this.props.id,
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => {
        const event = response.issueEvent
        switch(event.type) {
          case "close":
            this.setState(state => ({status: "close", events: [...state.events, event]}))
            break
          case "reopen":
            this.setState(state => ({status: "open", events: [...state.events, event]}))
            break
          case "title_update":
            this.setState(state => ({title: event.newTitle, events: [...state.events, event]}))
            break
        }
      }
    })
  }

  subscribeComments() {
    this.subscribeCommentCreate()
    this.subscribeCommentUpdate()
    this.subscribeCommentDelete()
  }

  subscribeCommentCreate() {
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
      id: this.props.id,
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentCreate(response.issueCommentCreate),
    })
  }

  subscribeCommentUpdate() {
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
      id: this.props.id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentUpdate(response.issueCommentUpdate)
    })
  }

  subscribeCommentDelete() {
    const subscription = graphql`
      subscription IssueCommentDeleteSubscription($id: ID!) {
        issueCommentDelete(id: $id) {
          id
        }
      }
    `

    const variables = {
      id: this.props.id
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.handleCommentDelete(response.issueCommentDelete)
    })
  }

  render() {
    const {title, titleEdit, number, insertedAt, author} = this.state
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
                  <div className="control">
                    <button className="button" onClick={() => this.setState({titleEdit: true})}>Edit</button>
                  </div>
                </div>
              )}
              {this.renderStatus()}
              &nbsp;
              <a href="{author.url}" className="has-text-black">{author.login}</a> opened this issue <time className="tooltip" dateTime={timestamp.format()}  data-tooltip={timestamp.format()}>{this.state.timestamp}</time>
            </div>
          </div>

          <div className="columns">
            <div className="column is-three-quarters">
              {this.renderFeed()}
            </div>
            <div className="column is-one-quarter">
            </div>
          </div>
        </div>
      )
    } else {
      return <div></div>
    }
  }

  renderFeed() {
    let comments = this.state.comments.slice()
    let events = this.state.events.slice()
    let firstComment = comments.shift()
    let items = comments.map(comment => ({type: "comment", timestamp: new Date(comment.insertedAt).getTime(), comment: comment}))
    items = items.concat(events.map(event => ({type: "event", timestamp: new Date(event.timestamp).getTime(), event: event})))
    items.sort((a, b) => a.timestamp - b.timestamp)

    return (
      <div className="thread">
        <Comment comment={firstComment} onUpdate={this.handleCommentUpdate} deletable={false} />
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
                      <Comment comment={item.comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
                    </div>
                  </div>
                )
              case "event":
                return <IssueEvent key={index} event={item.event} />
            }
          })}
          <div className="timeline-item">
            <div className="timeline-content">
              {this.renderForm()}
            </div>
          </div>
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

  renderForm() {
    const {status, editable} = this.state
    if(!editable) {
      return <CommentForm action="new" onSubmit={this.handleFormSubmit} />
    } else {
      switch(status) {
        case "open":
          return <CommentForm action="close" onSubmit={this.handleFormSubmit} onClose={this.handleClose} />
        case "close":
          return <CommentForm action="reopen" onSubmit={this.handleFormSubmit} onReopen={this.handleReopen} />
      }
    }
  }

  handleTitleFormSubmit(event) {
    const title = event.target.title.value
    if(title != "") {
      const variables = {
        id: this.props.id,
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
        onCompleted: (response, errors) => {
          this.setState({title: response.updateIssueTitle.title, titleEdit: false})
        }
      })
    }
    event.preventDefault()
  }

  handleFormSubmit(body) {
    if(body != "") {
      const variables = {
        id: this.props.id,
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
        onCompleted: (response, errors) => {
          this.handleCommentCreate(response.createIssueComment)
        }
      })
    }
  }

  handleClose() {
    const variables = {
      id: this.props.id,
    }

    const mutation = graphql`
      mutation IssueCloseMutation($id: ID!) {
        closeIssue(id: $id) {
          status
          editable
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        this.setState({status: response.closeIssue.status, editable: response.closeIssue.editable})
      }
    })
  }

  handleReopen() {
    const variables = {
      id: this.props.id,
    }

    const mutation = graphql`
      mutation IssueReopenMutation($id: ID!) {
        reopenIssue(id: $id) {
          status
          editable
        }
      }
    `

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        this.setState({status: response.reopenIssue.status, editable: response.reopenIssue.editable})
      }
    })
  }

  handleCommentCreate(comment) {
    this.setState(state => ({comments: state.comments.find(oldComment => oldComment.id == comment.id) ? state.comments : [...state.comments, comment]}))
  }

  handleCommentUpdate(comment) {
    this.setState(state => ({comments: state.comments.map(oldComment => oldComment.id === comment.id ? {...oldComment, ...comment} : oldComment)}))
  }
  handleCommentDelete(comment) {
    this.setState(state => ({comments: state.comments.filter(oldComment => oldComment.id !== comment.id)}))
  }
}

export default Issue
