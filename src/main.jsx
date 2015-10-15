(function() {

let App = React.createClass({
  getInitialState: function() {
    return {
      slURL: nPose.util.parseURL(nPose.util.getParam('api_url')),
      path: '',
      loading: true,
      items: []
    };
  },

  buildURL: function(path) {
    let url = this.state.slURL;

    return url.protocol + '//'
      + url.host
      + url.pathname
      + path
      + url.search;
  },

  componentDidMount: function() {
    this.getData(this.state.path,
      data => this.setState({
        items: data,
        loading: false
    }));
  },

  setPath: function(path) {
    this.setState({
      items: [],
      path: path,
      loading: true
    });
    this.getData(path, data => this.setState({
      items: data,
      loading: false
    }));
  },

  handleItemClick: function(item) {
    let itemPath = this.state.path;
    itemPath += encodeURIComponent(item.name);
    if (!itemPath.endsWith('/')) {
      itemPath += '/';
    }
    if (item.hasChildren) {
      this.setPath(itemPath);
    } else {
      // no children.  so just let the object know that a menu item was clicked,
      // but don't nav anywhere by changing this.state.path.
      this.setState({loading: true});
      this.getData(itemPath, () => this.setState({loading: false}));
    }
  },

  getData: function(path, cb) {
    let url = this.buildURL(path);
    JSONP(url, cb);
  },

  render: function() {
    return <PoseUI
      path={this.state.path}
      items={this.state.items}
      setPath={this.setPath}
      handleItemClick={this.handleItemClick}
      loading={this.state.loading}
    />;
  }
});

let PoseUI = React.createClass({
	getThumbs: function() {
		if (this.props.loading) {
			return <Loading />;
		}

		return <Thumbs items={this.props.items} path={this.props.path} handleItemClick={this.props.handleItemClick} />;
	},

  render: function() {
    return <div>
      <Nav path={this.props.path} setPath={this.props.setPath} />
			{this.getThumbs()} 
    </div>;
  }

});

let Nav = React.createClass({
  render: function() {
    // filter out nulls and empties
    let parts = this.props.path.split('/').filter(p => p);
    // we want first item to be empty for logo/home
    parts.splice(0, 0, "");
    let nodes = [];
    for (let p in parts) {
      let path = parts.slice(0, p + 1).join('/');
      nodes.push(<div className="nav-item" key={path} path={path} onClick={() => this.props.setPath(path)}>
        {p === '0' ? <Logo /> : parts[p]}
      </div>);
    }
    return <div className="nav">
      {nodes}
    </div>;
  }
});

let Logo = React.createClass({
  render: function () {
    return <span className="logo">nPose</span>;
  }
});

let Thumbs = React.createClass({
  renderItem: function(item) {
    return <div className="tile" key={item.name}
      name={item.name} onClick={() => this.props.handleItemClick(item)}>
      {item.thumb ? <SLThumb uuid={item.thumb} className="tile-thumb" /> : ''}
      <div className="tile-name">{item.name}</div>
    </div>;
  },

  render: function() {
    return <div className="tiles">{this.props.items.map(this.renderItem)}</div>;
  }
});

let SLThumb = React.createClass({
  render: function() {
    let url = `http://secondlife.com/app/image/${this.props.uuid}/1`;
    return <div className={this.props.className}>
      <img className="tile-thumb-img" src={url} />
    </div>;
  }
});

let Loading = React.createClass({
	render: function() {
		return <div className="loading"></div>;
	}
});

var container = document.createElement('div');
container.setAttribute('id', 'content');
document.body.appendChild(container);
ReactDOM.render(<App />, container);
})();
