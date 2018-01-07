<template>
  <ul>
    <li v-for="entry in tree">
      <div v-if="entry.type == 'tree'">
        <router-link :to="entry.path" append>{{ entry.path }}</router-link>
      </div>
      <div v-else-if="entry.type == 'blob'">
        <router-link to="">{{ entry.path }}</router-link>
      </div>
    </li>
  </ul>
</template>

<script>
import API from '../api';

let api = new API();

export default {
  props: {
    username: {type: String, required: true},
    repoPath: {type: String, required: true},
    repoSpec: {type: String, required: true},
    treePath: {type: String, default: ''}
  },
  watch: {
    $route: 'fetchTree'
  },
  methods: {
    fetchTree() {
      api.browseTree(this.username, this.repoPath, this.repoSpec, this.treePath)
      .then(tree => {
        this.tree = tree
        console.log(tree)
      }).catch(e => {
        this.errors.push(e)
      })
    }
  },
  data() {
    return {
      tree: {},
      errors: [],
    }
  },
  created() {
    this.fetchTree()
  },
}
</script>

