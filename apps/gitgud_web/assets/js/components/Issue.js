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
    this.subscribeStatus = this.subscribeStatus.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.renderStatus = this.renderStatus.bind(this)
    this.renderThread = this.renderThread.bind(this)
    this.renderComments = this.renderComments.bind(this)
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
      comments: []
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
          comments: response.node.comments
        })
        this.subscribeStatus()
        this.subscribeComments()
      })
  }

  subscribeStatus() {
    const subscription = graphql`
      subscription IssueStatusSubscription($id: ID!) {
        issueStatus(id: $id) {
          status
        }
      }
    `

    const variables = {
      id: this.props.id,
    }

    return requestSubscription(environment, {
      subscription,
      variables,
      onNext: response => this.setState({status: response.issueStatus.status})
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
              <div className="thread">
                {this.renderThread()}
              </div>
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

  renderStatus() {
    const {status} = this.state
    switch(status) {
      case "open":
        return <p className="tag is-success"><span className="icon"><i className="fa fa-exclamation-circle"></i></span><span>Open</span></p>
      case "close":
        return <p className="tag is-danger"><span className="icon"><i className="fa fa-check-circle"></i></span><span>Closed</span></p>
    }
  }

  renderThread() {
    let comments = this.state.comments.slice()
    let firstComment = comments.shift()
    return (
      <div className="thread">
        <Comment comment={firstComment} onUpdate={this.handleCommentUpdate} deletable={false} />
        <header>
          <h2 className="subtitle">{comments.length == 1 ? "1 comment" : `${comments.length} comments`}</h2>
        </header>
        {this.renderComments(comments)}
        {this.renderForm()}
      </div>
    )
  }

  renderComments(comments) {
    return comments.map((comment, index) =>
      <Comment key={index} comment={comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
    )
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
