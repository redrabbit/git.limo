import React from "react"
import ReactDOM from "react-dom"

import {fetchQuery, commitMutation, requestSubscription, graphql} from "react-relay";

import environment from "../relay-environment"

import Comment from "./Comment"
import CommentForm from "./CommentForm"

class IssueThread extends React.Component {
  constructor(props) {
    super(props)
    this.fetchIssue = this.fetchIssue.bind(this)
    this.subscribeComments = this.subscribeComments.bind(this)
    this.subscribeCommentCreate = this.subscribeCommentCreate.bind(this)
    this.subscribeCommentUpdate = this.subscribeCommentUpdate.bind(this)
    this.subscribeCommentDelete = this.subscribeCommentDelete.bind(this)
    this.renderComments = this.renderComments.bind(this)
    this.renderForm = this.renderForm.bind(this)
    this.handleFormSubmit = this.handleFormSubmit.bind(this)
    this.handleClose = this.handleClose.bind(this)
    this.handleReopen = this.handleReopen.bind(this)
    this.handleCommentCreate = this.handleCommentCreate.bind(this)
    this.handleCommentUpdate = this.handleCommentUpdate.bind(this)
    this.handleCommentDelete = this.handleCommentDelete.bind(this)
    this.state = {
      comments: []
    }
  }

  componentDidMount() {
    this.fetchIssue()
  }

  fetchIssue() {
    const query = graphql`
      query IssueThreadQuery($id: ID!) {
        node(id: $id) {
          ... on Issue {
            comments {
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
        }
      }
    `
    const variables = {
      id: this.props.id
    }

    fetchQuery(environment, query, variables)
      .then(response => {
        this.setState({comments: response.node.comments})
        this.subscribeComments()
      })
  }

  subscribeComments() {
    this.subscribeCommentCreate()
    this.subscribeCommentUpdate()
    this.subscribeCommentDelete()
  }

  subscribeCommentCreate() {
    const subscription = graphql`
      subscription IssueThreadCommentCreateSubscription($id: ID!) {
        issueCommentCreate(id: $id) {
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
      subscription IssueThreadCommentUpdateSubscription($id: ID!) {
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
      subscription IssueThreadCommentDeleteSubscription($id: ID!) {
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
    return (
      <div className="thread">
        <header>
          <h2 className="subtitle">{this.state.comments.length == 1 ? "1 comment" : `${this.state.comments.length} comments`}</h2>
        </header>
        {this.renderComments()}
        {this.renderForm()}
      </div>
    )
  }

  renderComments() {
    return this.state.comments.map((comment, index) =>
      <Comment key={index} comment={comment} onUpdate={this.handleCommentUpdate} onDelete={this.handleCommentDelete} />
    )
  }

  renderForm() {
    return <CommentForm action="close" onSubmit={this.handleFormSubmit} onClose={this.handleClose} />
  }

  handleFormSubmit(body) {
    const variables = {
      id: this.props.id,
      body: body
    }

    const mutation = graphql`
      mutation IssueThreadCreateCommentMutation($id: ID!, $body: String!) {
        createIssueComment(id: $id, body: $body) {
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

    commitMutation(environment, {
      mutation,
      variables,
      onCompleted: (response, errors) => {
        this.handleCommentCreate(response.createIssueComment)
      }
    })
  }

  handleClose() {
  }

  handleReopen() {
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

export default IssueThread
