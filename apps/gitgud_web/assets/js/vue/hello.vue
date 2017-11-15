<template>
  <div>
    <ul v-if="branches">
      <li v-for="branch of branches">
        <p><strong>{{branch.name}}</strong></p>
        <p>{{branch.sha}}</p>
      </li>
    </ul>

    <ul v-if="errors && errors.length">
      <li v-for="error of errors">
        {{error.message}}
      </li>
    </ul>
  </div>
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

  // Fetches posts when the component is created.
  created() {
    axios.get(`http://localhost:4000/api/users/redrabbit/repos/project-awesome/branches`)
    .then(response => {
      this.branches = response.data.branches
    })
    .catch(e => {
      this.errors.push(e)
    })
  }
}
</script>
