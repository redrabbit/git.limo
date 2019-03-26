import React from "react"

class CommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.bodyInput = React.createRef()
    this.handleSubmit = this.handleSubmit.bind(this)
    this.state = {submitEnabled: false}
  }

  componentDidMount() {
    this.bodyInput.current.focus()
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <div className="field">
          <div className="control">
            <textarea name="comment[body]"className="textarea" placeholder="Leave a comment" ref={this.bodyInput} onChange={(event) => this.setState({submitEnabled: !!event.target.value})} />
          </div>
        </div>
        <div className="field is-grouped">
          <div className="control">
            <button className="button" onClick={this.props.onCancel}>Cancel</button>
          </div>
          <div className="control">
            <button className="button is-success" type="submit" disabled={!this.state.submitEnabled}>Add comment</button>
          </div>
        </div>
      </form>
    )
  }

  handleSubmit(event) {
    event.preventDefault()
    this.props.onSubmit(this.bodyInput.current.value)
    this.bodyInput.current.value = ""
    this.setState({submitEnabled: false})
  }
}

export default CommentForm
