import axios from 'axios'

import Router from 'vue-router'
import Browser from './vue/repo/browser.vue'

Vue.use(Router)

const router = new Router({
  routes: [
    {path: '/tree/:spec/:tree*', name: 'browser', component: Browser, props: true}
  ],
  mode: 'history',
  saveScrollPosition: true
})

new Vue({
  router,
  el: '#app',
  components: { Browser }
});
