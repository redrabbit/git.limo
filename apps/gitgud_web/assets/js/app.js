import axios from 'axios'

import VueRouter from 'vue-router'

import User from './components/user.vue'
import Repo from './components/repo.vue'
import Browser from './components/browser.vue'

const router = new VueRouter({
  routes: [
    { path: '/:username',
      name: 'user',
      component: User,
      props: true,
    },
    { path: '/:username/:repoPath',
      name: 'repo',
      component: Repo,
      props: true,
      children: [
        { path: 'tree/:repoSpec/:treePath*',
          name: 'browser',
          component: Browser,
          props: true
        }
      ],
    }
  ],
  mode: 'history',
  saveScrollPosition: true
})

const app = new Vue({
  router,
}).$mount('#app')
