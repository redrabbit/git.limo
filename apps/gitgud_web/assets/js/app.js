import axios from 'axios'

import VueRouter from 'vue-router'

import Browser from './components/browser.vue'
import UserProfile from './components/user_profile.vue'

const router = new VueRouter({
  routes: [
    { path: '/:user',
      name: 'user',
      component: UserProfile,
      props: true,
      children: [
        { path: ':repo/tree/:spec/:path*',
          name: 'browser',
          component: Browser,
          props: true
        }
      ]
    }
  ],
  mode: 'history',
  saveScrollPosition: true
})

const app = new Vue({
  router,
}).$mount('#app')
