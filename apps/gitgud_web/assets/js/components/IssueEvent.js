import React from "react"

import moment from "moment"

class IssueEvent extends React.Component {
  constructor(props) {
    super(props)
    this.formatTimestamp = this.formatTimestamp.bind(this)
    this.state = {timestamp: moment.utc(this.props.event.timestamp).fromNow()}
  }

  componentDidMount() {
    this.interval = setInterval(this.formatTimestamp, 3000)
  }

  render() {
    const {event} = this.props
    const timestamp = moment.utc(event.timestamp)
    switch(event.type) {
      case "close":
        return (
          <div className="timeline-item">
            <div className="timeline-marker is-icon is-danger">
              <i className="fa fa-check"></i>
            </div>
            <div className="timeline-content">
              <a href={event.user.url} className="has-text-black">{event.user.login}</a> closed this issue <time className="tooltip" dateTime={timestamp.format()}  data-tooltip={timestamp.format()}>{this.state.timestamp}</time>
            </div>
          </div>
        )
      case "reopen":
        return (
          <div className="timeline-item">
            <div className="timeline-marker is-icon is-success">
              <i className="fa fa-redo"></i>
            </div>
            <div className="timeline-content">
              <a href={event.user.url} className="has-text-black">{event.user.login}</a> reopened this issue <time className="tooltip" dateTime={timestamp.format()}  data-tooltip={timestamp.format()}>{this.state.timestamp}</time>
            </div>
          </div>
        )
      case "title_update":
        return (
          <div className="timeline-item">
            <div className="timeline-marker is-icon">
              <i className="fa fa-pen"></i>
            </div>
            <div className="timeline-content">
              <a href={event.user.url} className="has-text-black">{event.user.login}</a> changed the title <em className="has-text-black"><s>{event.oldTitle}</s></em> to <em className="has-text-black">{event.newTitle}</em>
              &nbsp;<time className="tooltip" dateTime={timestamp.format()}  data-tooltip={timestamp.format()}>{this.state.timestamp}</time>
            </div>
          </div>
        )
    }
  }

  formatTimestamp() {
    this.setState({timestamp: moment.utc(this.props.event.timestamp).fromNow()})
  }
}

export default IssueEvent
