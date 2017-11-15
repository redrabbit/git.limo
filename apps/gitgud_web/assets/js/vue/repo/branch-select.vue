<template>
    <select v-if="branches.length">
      <option v-for="branch of branches" :value="branch.sha">{{ branch.name }}</option>
    </select>
</template>

<script>
import axios from 'axios';

export default {
  data() {
    return {
      branches: [],
      errors: []
    }
  },

  created() {
    axios.get(`/api/users/redrabbit/repos/project-awesome/branches`)
    .then(response => {
      this.branches = response.data.branches
    })
    .catch(e => {
      this.errors.push(e)
    })
  }
}
</script>
