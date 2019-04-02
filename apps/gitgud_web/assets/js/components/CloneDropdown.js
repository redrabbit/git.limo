import React from "react"

class CloneDropdown extends React.Component {
  constructor(props) {
    super(props)
    this.dropdown = React.createRef()
    this.input = React.createRef()
    this.renderDropdown = this.renderDropdown.bind(this)
    this.handleToggle = this.handleToggle.bind(this)
    this.handleProtocol = this.handleProtocol.bind(this)
    this.handleCopyToClipboard = this.handleCopyToClipboard.bind(this)
    this.state = {toggled: false, protocol: "http"}
  }

  render() {
    return (
      <div className="dropdown is-right" ref={this.dropdown}>
        <div className="dropdown-trigger">
          <button className="button is-success" aria-haspopup="true" aria-controls="dropdown-menu" onClick={this.handleToggle}>
            <span>Clone repository</span>
            <span className="icon is-small">
              <i className="fas fa-angle-down" aria-hidden="true"></i>
            </span>
          </button>
        </div>
        <div className="dropdown-menu" role="menu">
          {this.renderDropdown()}
        </div>
      </div>
    )
  }

  renderDropdown() {
    switch(this.state.protocol) {
      case "http":
        return (
          <div className="dropdown-content">
            <div className="dropdown-item">
              {this.props.sshUrl && <a className="is-pulled-right" onClick={this.handleProtocol("ssh")}>with SSH</a>}
              <div className="field">
                <label className="label">Clone with HTTP</label>
                <div className="field has-addons">
                  <div className="control is-expanded">
                    <input className="input is-small" type="text" value={this.props.httpUrl} readOnly={true} ref={this.input} />
                  </div>
                  <div className="control">
                    <a className="button is-small" onClick={this.handleCopyToClipboard}>
                      <span className="icon is-small">
                        <i className="fa fa-clipboard"></i>
                      </span>
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )
      case "ssh":
        return (
          <div className="dropdown-content">
            <div className="dropdown-item">
              {this.props.httpUrl && <a className="is-pulled-right" onClick={this.handleProtocol("http")}>with HTTP</a>}
              <div className="field">
                <label className="label">Clone with SSH</label>
                <div className="field has-addons">
                  <div className="control is-expanded">
                    <input className="input is-small" type="text" value={this.props.sshUrl} readOnly={true} ref={this.input} />
                  </div>
                  <div className="control">
                    <a className="button is-small" onClick={this.handleCopyToClipboard}>
                      <span className="icon is-small">
                        <i className="fa fa-clipboard"></i>
                      </span>
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )
    }
  }

  handleToggle() {
    const toggled = this.state.toggled
    if(!toggled)
      this.dropdown.current.classList.add("is-active")
    else
      this.dropdown.current.classList.remove("is-active")
    this.setState({toggled: !toggled})
  }

  handleProtocol(proto) {
    return () => this.setState({protocol: proto})
  }

  handleCopyToClipboard() {
    this.input.current.focus()
    this.input.current.select()
    document.execCommand("copy")
    this.input.current.blur()
  }
}

export default CloneDropdown
