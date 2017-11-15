<template>
  <div>
    <pre v-if="blob">
      {{ blob }}
    </pre>
    <ul v-if="tree.length">
      <li v-for="entry in tree">
        <router-link :to="entry.path" append>{{ entry.path }}</router-link>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from 'axios';

export default {
  data() {
    return {
      tree: [],
      blob: null,
      errors: []
    }
  },
  created() {
    this.requestTree()
  },
  methods: {
    requestTree() {
      const spec = this.$route.params.spec
      const path = this.$route.params.tree || ''
      axios.get(`/api/users/redrabbit/repos/project-awesome/tree/${spec}/${path}`, {headers: {'Accept': 'application/json'}})
      .then(response => {
        const tree = response.data.tree
        switch(tree.type) {
          case 'tree':
            this.tree = tree.tree
            this.blob = null
            break;
          case 'blob':
            this.blob = tree.blob
            this.tree = []
            break;
        }
      })
      .catch(e => {
        this.errors.push(e)
      })
    }
  },
  watch: {
    '$route.params.tree': function(path) {
      this.requestTree()
    }
  }
}
</script>

