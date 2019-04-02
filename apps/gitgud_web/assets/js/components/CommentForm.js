import React from "react"

import {fetchQuery, graphql} from "relay-runtime"

import environment from "../relay-environment"

class CommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.bodyInput = React.createRef()
    this.fetchComment = this.fetchComment.bind(this)
    this.handleSubmit = this.handleSubmit.bind(this)
    this.state = {body: props.body || ""}
  }

  componentDidMount() {
    this.bodyInput.current.focus()
    this.fetchComment()
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <div className="field">
          <div className="control">
            <textarea name="comment[body]"className="textarea" placeholder="Leave a comment" value={this.state.body} onChange={event => this.setState({body: event.target.value})} ref={this.bodyInput} />
          </div>
        </div>
        <div className="field is-grouped">
          <div className="control">
            <button className="button" type="reset" onClick={this.props.onCancel}>Cancel</button>
          </div>
          <div className="control">
            <button className="button is-success" type="submit" disabled={this.state.body === ""}>Add comment</button>
          </div>
        </div>
      </form>
    )
  }

  fetchComment() {
    if(this.props.id) {
      const query = graphql`
        query CommentFormCommentQuery($comment: ID!) {
          node(id: $comment) {
            ... on Comment {
              body
            }
          }
        }
      `
      const variables = {
        comment: this.props.id
      }

      fetchQuery(environment, query, variables)
        .then(response => this.setState({body: response.node.body}))
    }
  }

  handleSubmit(event) {
    event.preventDefault()
    this.props.onSubmit(this.state.body)
    this.setState({body: ""})
  }
}

export default CommentForm
