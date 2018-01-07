<template>
  <div>
    <h2>{{ username }}</h2>
    <ul>
      <li v-for="repo in repos">
        <router-link :to="{ name: 'repo', params: { repoPath: repo.path }}">{{ repo.name }}</router-link>
      </li>
    </ul>
  </div>
</template>

<script>
import API from '../api';

let api = new API()

export default {
  props: {
    username: {type: String, required: true},
  },
  methods: {
    fetchUser() {
      this.fetchUserRepos()
    },
    fetchUserRepos() {
      api.listUserRepos(this.username)
        .then(repos => {
          this.repos = repos
        }).catch(e => {
          this.errors.push(e)
        })
    }
  },
  created() {
    this.fetchUser()
  },
  data() {
    return {
      repos: [],
      errors: [],
    }
  },
}
</script>

