import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery, commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"

import moment from "moment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

class Issue extends React.Component {
  constructor(props) {
    super(props)
    this.fetchIssue = this.fetchIssue.bind(this)
    this.subscribeEvents = this.subscribeEvents.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.renderFeed = this.renderFeed.bind(this)
    this.renderStatus = this.renderStatus.bind(this)
    this.renderEvent = this.renderEvent.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleClose = this.handleClose.bind(this)
    this.handleReopen = this.handleReopen.bind(this)
    this.handleCommentCreate = this.handleCommentCreate.bind(this)
    this.handleCommentUpdate = this.handleCommentUpdate.bind(this)
    this.handleCommentDelete = this.handleCommentDelete.bind(this)
    this.state = {
      title: null,
      author: null,
      status: null,
      number: null,
      insertedAt: null,
      editable: false,
      comments: [],
      events: []
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
          events: response.node.events
        })
        this.subscribeEvents()
        this.subscribeComments()
      })
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
        console.log(event)
        switch(event.type) {
          case "close":
            this.setState(state => ({status: "close", events: [...state.events, event]}))
            break
          case "reopen":
            this.setState(state => ({status: "open", events: [...state.events, event]}))
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
    const {title, number, insertedAt, author} = this.state
    if(number) {
      const timestamp = moment.utc(insertedAt)
      return (
        <div>
          <div className="columns">
            <div className="column is-12">
              <h1 className="title">{title} <span className="has-text-grey-light">#{number}</span></h1>
              {this.renderStatus()}
              &nbsp;
              <a href="{author.url}" className="has-text-black">{author.login}</a> opened this issue <time className="tooltip" date-time={timestamp.format()}  data-tooltip={timestamp.format()}>{timestamp.fromNow()}</time>
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
                return this.renderEvent(item.event, index)
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

  renderEvent(event, index) {
    const timestamp = moment.utc(event.timestamp)
    switch(event.type) {
      case "close":
        return (
          <div key={index} className="timeline-item">
            <div className="timeline-marker is-icon is-danger">
              <i className="fa fa-check"></i>
            </div>
            <div className="timeline-content">
              <a href={event.user.url} className="has-text-black">{event.user.login}</a> closed this issue <time className="tooltip" date-time={timestamp.format()}  data-tooltip={timestamp.format()}>{timestamp.fromNow()}</time>
            </div>
          </div>
        )
      case "reopen":
        return (
          <div key={index} className="timeline-item">
            <div className="timeline-marker is-icon is-success">
              <i className="fa fa-redo"></i>
            </div>
            <div className="timeline-content">
              <a href={event.user.url} className="has-text-black">{event.user.login}</a> reopened this issue <time className="tooltip" date-time={timestamp.format()}  data-tooltip={timestamp.format()}>{timestamp.fromNow()}</time>
            </div>
          </div>
        )
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
