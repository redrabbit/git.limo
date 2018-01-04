import axios from 'axios';

export default class API {
  constructor(...args) {
    this.http = axios.create({
      headers: {
        'Accept': 'application/json'
      }
    })

    this.http.interceptors.request.use(conf => {
      conf.data = conf.data // TODO
      return conf
    }, err => {
      return Promise.reject(err)
    })

    this.http.interceptors.response.use(rep => {
      rep.data = rep.data // TODO
      return rep
    }, err => {
      err.data = err.data // TODO
      return Promise.reject(err)
    })
  }

  isAuthenticated() {
    return this.authToken != undefined
  }

  authenticate(username, password) {
    return this.getUserToken(username, password)
      .then(auth => {
        this.authUser = username
        this.authToken = auth.token
        this.http.defaults.headers.common['Authorization'] = `Bearer ${this.authToken}`
        return auth
      })
  }

  getUserToken(username, password) {
    return this.http.post('/api/token', {username: username, password: password })
      .then(rep => rep.data)
  }

  // user repos

  listUserRepos(user) {
    return this.http.get(`/api/users/${user}/repos`)
      .then(rep => rep.data)
  }

  getUserRepo(user, repo) {
    return this.http.get(`/api/users/${user}/repos/${repo}`)
      .then(rep => rep.data)
  }

  updateUserRepo(user, repo, params) {
    return this.http.put(`/api/users/${user}/repos/${repo}`, params)
      .then(rep => rep.data)
  }

  // own repos

  listRepos() {
    return this.listUserRepos(this.authUser)
  }

  getRepo(repo) {
    return this.getUserRepo(this.authUser, repo)
  }

  createRepo(params) {
    return this.http.post(`/api/users/${this.authUser}/repos`, params)
      .then(rep => rep.data)
  }

  updateRepo(repo, params) {
    return this.updateUserRepo(this.authUser, repo, params)
  }

  deleteRepo(repo) {
    return this.http.delete(`/api/users/${this.authUser}/repos/${repo}`)
      .then(rep => rep.data)
  }

  // branches

  listBranches(user, repo) {
    return this.http.get(`/api/users/${user}/repos/${repo}/branches`)
      .then(rep => rep.data)
  }

  getBranch(user, repo, branch) {
    return this.http.get(`/api/users/${user}/repos/${repo}/branches/${branch}`)
      .then(rep => rep.data)
  }

  createBranch(user, repo, params) {
    return this.http.post(`/api/users/${user}/repos/${repo}/branches`, params)
      .then(rep => rep.data)
  }

  updateBranch(user, repo, branch, params) {
    return this.http.put(`/api/users/${user}/repos/${repo}/branches/${branch}`, params)
      .then(rep => rep.data)
  }

  deleteBranch(user, repo, branch) {
    return this.http.delete(`/api/users/${user}/repos/${repo}/branches/${branch}`)
      .then(rep => rep.data)
  }

  // commits

  getCommit(user, repo, spec) {
    return this.http.get(`/api/users/${user}/repos/${repo}/commits/${spec}`)
      .then(rep => rep.data)
  }

  revWalk(user, repo, spec) {
    return this.http.get(`/api/users/${user}/repos/${repo}/revwalk/${spec}`)
      .then(rep => rep.data)
  }


  // trees

  browseTree(user, repo, spec, path) {
    return this.http.get(`/api/users/${user}/repos/${repo}/tree/${spec}/${path}`)
      .then(rep => rep.data)
  }
}
