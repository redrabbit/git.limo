import React from "react"
import ReactDOM from "react-dom"

class CommentForm extends React.Component {
  constructor(props) {
    super(props)
    this.handleCancel = this.handleCancel.bind(this)
    this.bodyInput = React.createRef()
    this.state = {folded: !!props.reply}
  }

  componentDidUpdate(prevProps, prevState) {
    if(prevState.folded && !this.state.folded) {
      this.bodyInput.current.focus();
    }
  }

  render() {
    if(this.state.folded) {
      return (
        <div className="box">
          <div className="field">
            <div className="control">
              <input name="comment[body]" className="input" placeholder="Leave a comment" ref={this.bodyInput} onFocus={() => this.setState({folded: false})} />
            </div>
          </div>
        </div>
      )
    } else {
      return (
        <div className="box">
          <div className="field">
            <div className="control">
              <textarea name="comment[body]"className="textarea" placeholder="Leave a comment" ref={this.bodyInput} />
            </div>
          </div>
          <div className="field is-grouped">
            <div className="control">
              <button className="button" onClick={this.handleCancel}>Cancel</button>
            </div>
            <div className="control">
              <button className="button is-success">Add comment</button>
            </div>
          </div>
        </div>
      )
    }
  }

  handleCancel() {
    if(this.props.reply) {
      this.setState({folded: true})
    } else {
      let node = ReactDOM.findDOMNode(this)
      let tr = node.closest("tr")
      ReactDOM.unmountComponentAtNode(node.parentNode)
      tr.parentNode.removeChild(tr)
    }
  }
}

export default CommentForm
