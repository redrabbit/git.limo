alias GitGud.User

{:ok, user} = User.insert(username: "redrabbit", name: "Mario Flach", email: "m.flach@almightycouch.com", password: "michael")
{:ok, _key} = User.put_ssh_key(user, "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCuTxpQMuEr1PQBCv17emvQm/7EoEYI/REez45LTYWk7v+gU8H6nWYbvN6pXcx6wDa+jvbQI/FddRy4KUIYrNOsmiPzgPoHf6lgt25ysnEOoI9webXs3cluHp1jMXOzCeaMwvFBb6bUHc02Wv8IuInByg7AFJHkNZdbNks6SVHi7DH/mdvWCbIZ2wbcYJx1v9PhtLQ6Q1IGy+jKej7hEPPz7OeKMuIb5K4epXAuWHlMydwzqvkZUinTu/6GvjJIpGTOyKF0eKM7E8nszzm3iAxXn5DQrNIvLvC0Wvaz4u9JV37jGYQZfy/8npf3AWOdJTHQ15ZJQbgqMdMNAQNt8QVr info@almightycouch.org")
