<template>
  <div>
    <h2>{{ repo.name }}</h2>
    <router-link :to="{ name: 'user', params: { username: repo.owner || username }}">{{ repo.owner }}</router-link> /
    <router-link :to="{ name: 'repo', params: { repoPath: repo.path || repoPath }}">{{ repo.path }}</router-link>
    <pre v-if="repo.description">{{ repo.description }}</pre>
    <router-view></router-view>
  </div>
</template>

<script>
import API from '../api';

let api = new API()

export default {
  props: {
    username: {type: String, required: true},
    repoPath: {type: String, required: true},
  },
  methods: {
    fetchRepo() {
      api.getUserRepo(this.username, this.repoPath)
        .then(repo => {
          this.repo = repo
        }).catch(e => {
          this.errors.push(e)
        })
    }
  },
  created() {
    this.fetchRepo()
  },
  data() {
    return {
      repo: {},
      errors: [],
    }
  },
}
</script>

