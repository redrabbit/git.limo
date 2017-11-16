<template>
  <div>
    <pre v-if="isBlob">
      {{ tree.blob }}
    </pre>
    <ul v-else-if="isTree">
      <li v-for="entry in tree.tree">
        <router-link :to="entry.path" append>{{ entry.path }}</router-link>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  props: {
    user: {type: String, required: true},
    repo: {type: String, required: true},
    spec: {type: String, required: true},
    path: {type: String, default: ''}
  },
  watch: {
    $route: 'requestTree'
  },
  computed: {
    isBlob() {
      return this.tree.type === 'blob'
    },
    isTree() {
      return this.tree.type === 'tree'
    },
  },
  methods: {
    requestTree() {
      axios.get(`/api/users/${this.user}/repos/${this.repo}/tree/${this.spec}/${this.path}`, {
        headers: {'Accept': 'application/json'}
      }).then(response => {
        this.tree = response.data.tree
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
    this.requestTree()
  },
}
</script>

